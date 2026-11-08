import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';

// ──────────────────────────────────────────────
// Simulation Models
// ──────────────────────────────────────────────

class YearlyProjection {
  final int year;
  final double remainingBalance;
  final double interestPaidThisYear;
  final double principalPaidThisYear;

  YearlyProjection({
    required this.year,
    required this.remainingBalance,
    required this.interestPaidThisYear,
    required this.principalPaidThisYear,
  });
}

class SimulationResult {
  final int totalMonths;
  final double totalInterest;
  final double totalPaid;
  final List<YearlyProjection> yearlyProjections;
  final List<double> monthlyBalances;

  SimulationResult({
    required this.totalMonths,
    required this.totalInterest,
    required this.totalPaid,
    required this.yearlyProjections,
    required this.monthlyBalances,
  });
}

// ──────────────────────────────────────────────
// Custom Trend Chart Painter
// ──────────────────────────────────────────────

class DebtTrendPainter extends CustomPainter {
  final List<double> baselineTrend;
  final List<double> acceleratedTrend;
  final Color baselineColor;
  final Color acceleratedColor;
  final Color gridColor;

  DebtTrendPainter({
    required this.baselineTrend,
    required this.acceleratedTrend,
    required this.baselineColor,
    required this.acceleratedColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Lines
    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (baselineTrend.isEmpty) return;

    // Find max coordinates
    final maxMonths = max(baselineTrend.length, acceleratedTrend.length).toDouble();
    final maxBalance = max(
      baselineTrend.isNotEmpty ? baselineTrend.first : 1.0,
      acceleratedTrend.isNotEmpty ? acceleratedTrend.first : 1.0,
    );

    if (maxBalance <= 0 || maxMonths <= 0) return;

    final divisorX = maxMonths > 1 ? maxMonths - 1 : 1.0;

    // 2. Draw Baseline Curve (Red/Orange - Standard Debt)
    final paintBaseline = Paint()
      ..color = baselineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathBaseline = Path();
    for (var i = 0; i < baselineTrend.length; i++) {
      final x = size.width * (i / divisorX);
      final y = size.height * (1.0 - (baselineTrend[i] / maxBalance));
      if (i == 0) {
        pathBaseline.moveTo(x, y);
      } else {
        pathBaseline.lineTo(x, y);
      }
    }
    canvas.drawPath(pathBaseline, paintBaseline);

    // 3. Draw Accelerated Curve (Teal/Green - Rapid Payoff)
    if (acceleratedTrend.isNotEmpty) {
      final paintAccelerated = Paint()
        ..color = acceleratedColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final pathAccelerated = Path();
      for (var i = 0; i < acceleratedTrend.length; i++) {
        final x = size.width * (i / divisorX);
        final y = size.height * (1.0 - (acceleratedTrend[i] / maxBalance));
        if (i == 0) {
          pathAccelerated.moveTo(x, y);
        } else {
          pathAccelerated.lineTo(x, y);
        }
      }
      canvas.drawPath(pathAccelerated, paintAccelerated);
    }
  }

  @override
  bool shouldRepaint(covariant DebtTrendPainter oldDelegate) => true;
}

// ──────────────────────────────────────────────
// Debt Calculator Page
// ──────────────────────────────────────────────

class DebtCalculatorPage extends StatefulWidget {
  final VoidCallback onBack;

  const DebtCalculatorPage({super.key, required this.onBack});

  @override
  State<DebtCalculatorPage> createState() => _DebtCalculatorPageState();
}

class _DebtCalculatorPageState extends State<DebtCalculatorPage> {
  // Inputs
  double _principal = 1000000; // 10 Lakhs default
  double _annualRate = 9.5;
  String _calcMode = 'term'; // 'term' (years) or 'payment' (EMI)
  int _repaymentTermYears = 15;
  double _customEmi = 12000;
  String _currency = 'INR';

  // Accelerators
  double _annualStepUp = 8.0; // 8% increase per year
  double _extraMonthly = 2000;
  double _lumpSumAmount = 50000;
  int _lumpSumMonth = 12; // At month 12

  // Controllers
  late TextEditingController _principalController;
  late TextEditingController _rateController;
  late TextEditingController _termController;
  late TextEditingController _emiController;
  late TextEditingController _stepUpController;
  late TextEditingController _extraMonthlyController;
  late TextEditingController _lumpSumAmountController;
  late TextEditingController _lumpSumMonthController;

  String _outputTab = 'summary'; // 'summary' or 'schedule'
  String get _currencySymbol => _currency == 'INR' ? '₹' : r'$';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _principalController = TextEditingController(text: _principal.round().toString());
    _rateController = TextEditingController(text: _annualRate.toString());
    _termController = TextEditingController(text: _repaymentTermYears.toString());
    _emiController = TextEditingController(text: _customEmi.round().toString());
    _stepUpController = TextEditingController(text: _annualStepUp.toString());
    _extraMonthlyController = TextEditingController(text: _extraMonthly.round().toString());
    _lumpSumAmountController = TextEditingController(text: _lumpSumAmount.round().toString());
    _lumpSumMonthController = TextEditingController(text: _lumpSumMonth.toString());
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _termController.dispose();
    _emiController.dispose();
    _stepUpController.dispose();
    _extraMonthlyController.dispose();
    _lumpSumAmountController.dispose();
    _lumpSumMonthController.dispose();
    super.dispose();
  }

  // ── Database / Preference Operations ──

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCurrency = prefs.getString('debt_calc_currency');
    if (savedCurrency != null) {
      setState(() {
        _currency = savedCurrency;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('debt_calc_currency', _currency);
  }

  // ── Simulation Logic ──

  double _calculateEmiForTerm(double principal, double annualRate, int years) {
    final r = (annualRate / 100) / 12;
    final n = years * 12;
    if (r == 0) return principal / n;
    return principal * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
  }

  SimulationResult _simulate({
    required double principal,
    required double annualRate,
    required double baseMonthlyPayment,
    double stepUpPercent = 0.0,
    double extraMonthly = 0.0,
    double lumpSumVal = 0.0,
    int lumpSumMo = 0,
    bool accelerated = false,
  }) {
    final r = (annualRate / 100) / 12;
    double balance = principal;
    double totalInterest = 0;
    double totalPaid = 0;
    int monthsCount = 0;

    final yearlyProjections = <YearlyProjection>[];
    final monthlyBalances = <double>[principal];

    double interestThisYear = 0;
    double principalPaidThisYear = 0;
    double currentMonthlyBase = baseMonthlyPayment;

    while (balance > 0.01 && monthsCount < 600) {
      monthsCount++;

      // Apply annual payment step-up on accelerated path
      if (accelerated && monthsCount > 1 && (monthsCount - 1) % 12 == 0) {
        currentMonthlyBase = currentMonthlyBase * (1 + stepUpPercent / 100);
      }

      final interest = balance * r;

      // Calculate total planned payment for this month
      double payment = currentMonthlyBase;
      if (accelerated) {
        payment += extraMonthly;
        if (monthsCount == lumpSumMo) {
          payment += lumpSumVal;
        }
      }

      // Check if payment covers interest (Infinite Debt safety check)
      if (payment <= interest && r > 0) {
        return SimulationResult(
          totalMonths: -1,
          totalInterest: double.infinity,
          totalPaid: double.infinity,
          yearlyProjections: [],
          monthlyBalances: [],
        );
      }

      final actualPayment = min(payment, balance + interest);
      final principalPaid = actualPayment - interest;

      balance -= principalPaid;
      totalInterest += interest;
      totalPaid += actualPayment;

      interestThisYear += interest;
      principalPaidThisYear += principalPaid;
      monthlyBalances.add(max(0.0, balance));

      // Append yearly projections
      if (monthsCount % 12 == 0 || balance <= 0.01) {
        yearlyProjections.add(YearlyProjection(
          year: (monthsCount / 12).ceil(),
          remainingBalance: max(0.0, balance),
          interestPaidThisYear: interestThisYear,
          principalPaidThisYear: principalPaidThisYear,
        ));
        interestThisYear = 0;
        principalPaidThisYear = 0;
      }
    }

    return SimulationResult(
      totalMonths: monthsCount,
      totalInterest: totalInterest,
      totalPaid: totalPaid,
      yearlyProjections: yearlyProjections,
      monthlyBalances: monthlyBalances,
    );
  }

  // ── Formatting Helpers ──

  String _formatCurrency(double value) {
    if (value == double.infinity) return 'Unlimited';
    if (_currency == 'INR') return _formatIndian(value);
    return _formatUS(value);
  }

  String _formatIndian(double value) {
    final valStr = value.round().toString();
    if (valStr.length <= 3) return '$_currencySymbol$valStr';
    final lastThree = valStr.substring(valStr.length - 3);
    var remaining = valStr.substring(0, valStr.length - 3);
    final List<String> chunks = [];
    while (remaining.length > 2) {
      chunks.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) chunks.insert(0, remaining);
    return '$_currencySymbol${chunks.join(',')},$lastThree';
  }

  String _formatUS(double value) {
    final valStr = value.round().toString();
    final result = StringBuffer();
    int count = 0;
    for (int i = valStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result.write(',');
      result.write(valStr[i]);
      count++;
    }
    return '$_currencySymbol${result.toString().split('').reversed.join()}';
  }

  String _formatMonthsToYearsAndMonths(int totalMonths) {
    if (totalMonths == -1) return 'Infinite Debt';
    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;
    if (years == 0) return '$months month${months == 1 ? "" : "s"}';
    if (months == 0) return '$years year${years == 1 ? "" : "s"}';
    return '$years yr${years == 1 ? "" : "s"} $months mo${months == 1 ? "" : "s"}';
  }

  // ── Build UI ──

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1000;

    // 1. Calculate base monthly repayment
    double baseMonthly = 0.0;
    if (_calcMode == 'term') {
      baseMonthly = _calculateEmiForTerm(_principal, _annualRate, _repaymentTermYears);
    } else {
      baseMonthly = _customEmi;
    }

    // 2. Run simulations
    final baseline = _simulate(
      principal: _principal,
      annualRate: _annualRate,
      baseMonthlyPayment: baseMonthly,
      accelerated: false,
    );

    final accelerated = _simulate(
      principal: _principal,
      annualRate: _annualRate,
      baseMonthlyPayment: baseMonthly,
      stepUpPercent: _annualStepUp,
      extraMonthly: _extraMonthly,
      lumpSumVal: _lumpSumAmount,
      lumpSumMo: _lumpSumMonth,
      accelerated: true,
    );

    final hasInfiniteDebt = baseline.totalMonths == -1 || accelerated.totalMonths == -1;

    // Savings metrics
    double interestSavings = 0.0;
    int monthsSaved = 0;
    if (!hasInfiniteDebt) {
      interestSavings = max(0.0, baseline.totalInterest - accelerated.totalInterest);
      monthsSaved = max(0, baseline.totalMonths - accelerated.totalMonths);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: motion.PremiumEnterTransition(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.borderSubtle.withValues(alpha: 0.5),
                    ),
                    child: Icon(Icons.arrow_back, size: 16, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debt Repayment Calculator',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    Text(
                      'Analyze payoff times, step-up accelerated payoffs, and project long-term interest savings.',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                // Currency Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      _buildCurrencyButton('INR', 'Rupee (₹)', tokens),
                      _buildCurrencyButton('USD', r'Dollar ($)', tokens),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Columns
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column - Inputs
                        SizedBox(
                          width: 420,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: _buildInputsPanel(tokens),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right column - Projections & Results
                        Expanded(
                          child: _buildResultsPanel(
                            tokens: tokens,
                            baseline: baseline,
                            accelerated: accelerated,
                            interestSavings: interestSavings,
                            monthsSaved: monthsSaved,
                            hasInfiniteDebt: hasInfiniteDebt,
                            baseEmi: baseMonthly,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildInputsPanel(tokens),
                          const SizedBox(height: 24),
                          _buildResultsPanel(
                            tokens: tokens,
                            baseline: baseline,
                            accelerated: accelerated,
                            interestSavings: interestSavings,
                            monthsSaved: monthsSaved,
                            hasInfiniteDebt: hasInfiniteDebt,
                            baseEmi: baseMonthly,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Currency Selection Helper ──

  Widget _buildCurrencyButton(String code, String tooltip, ThemeTokens tokens) {
    final isSelected = _currency == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currency = code;
        });
        _savePreferences();
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? tokens.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Inputs Panel Layout ──

  Widget _buildInputsPanel(ThemeTokens tokens) {
    return Column(
      children: [
        // ── Primary Loan Inputs ──
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loan Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textSecondary),
              ),
              const SizedBox(height: 16),

              // Total Debt Principal
              _buildInputLabelRow(
                'Total Debt Principal',
                _formatCurrency(_principal),
                tokens,
              ),
              Slider(
                value: _principal,
                min: 10000,
                max: 10000000,
                divisions: 999,
                activeColor: tokens.accent,
                inactiveColor: tokens.borderSubtle,
                onChanged: (val) {
                  setState(() {
                    _principal = val;
                    _principalController.text = val.round().toString();
                  });
                },
              ),
              _buildTextInputField(
                controller: _principalController,
                onChanged: (text) {
                  final val = double.tryParse(text);
                  if (val != null) {
                    setState(() => _principal = val.clamp(1000, 100000000));
                  }
                },
                tokens: tokens,
                suffix: 'Principal Amount',
              ),
              const SizedBox(height: 20),

              // Annual Interest Rate
              _buildInputLabelRow(
                'Annual Interest Rate (APR)',
                '${_annualRate.toStringAsFixed(2)}%',
                tokens,
              ),
              Slider(
                value: _annualRate,
                min: 1.0,
                max: 25.0,
                divisions: 240,
                activeColor: tokens.accent,
                inactiveColor: tokens.borderSubtle,
                onChanged: (val) {
                  setState(() {
                    _annualRate = double.parse(val.toStringAsFixed(2));
                    _rateController.text = _annualRate.toString();
                  });
                },
              ),
              _buildTextInputField(
                controller: _rateController,
                onChanged: (text) {
                  final val = double.tryParse(text);
                  if (val != null) {
                    setState(() => _annualRate = val.clamp(0.1, 50.0));
                  }
                },
                tokens: tokens,
                suffix: '% Per Annum',
              ),
              const SizedBox(height: 20),

              // Calculation Mode Toggle
              Text(
                'Determine Payment Term By',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textMuted),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: tokens.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton('term', 'Repayment Term', tokens),
                    ),
                    Expanded(
                      child: _buildTabButton('payment', 'Monthly EMI', tokens),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Loan Term slider OR Custom EMI slider
              if (_calcMode == 'term') ...[
                _buildInputLabelRow(
                  'Repayment Term',
                  '$_repaymentTermYears years',
                  tokens,
                ),
                Slider(
                  value: _repaymentTermYears.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: tokens.accent,
                  inactiveColor: tokens.borderSubtle,
                  onChanged: (val) {
                    setState(() {
                      _repaymentTermYears = val.round();
                      _termController.text = _repaymentTermYears.toString();
                    });
                  },
                ),
                _buildTextInputField(
                  controller: _termController,
                  onChanged: (text) {
                    final val = int.tryParse(text);
                    if (val != null) {
                      setState(() => _repaymentTermYears = val.clamp(1, 50));
                    }
                  },
                  tokens: tokens,
                  suffix: 'Years',
                ),
              ] else ...[
                _buildInputLabelRow(
                  'Monthly Payment (Base EMI)',
                  _formatCurrency(_customEmi),
                  tokens,
                ),
                Slider(
                  value: _customEmi.clamp(1000.0, _principal / 2),
                  min: 1000,
                  max: min(_principal / 2, 500000),
                  divisions: 499,
                  activeColor: tokens.accent,
                  inactiveColor: tokens.borderSubtle,
                  onChanged: (val) {
                    setState(() {
                      _customEmi = val;
                      _emiController.text = val.round().toString();
                    });
                  },
                ),
                _buildTextInputField(
                  controller: _emiController,
                  onChanged: (text) {
                    final val = double.tryParse(text);
                    if (val != null) {
                      setState(() => _customEmi = val.clamp(100.0, _principal));
                    }
                  },
                  tokens: tokens,
                  suffix: 'Per Month',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Repayment Accelerators (Boosters) ──
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Accelerated Repayment Boosters',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Annual Payment Step-Up
              _buildInputLabelRow(
                'Annual Payment Step-Up',
                '${_annualStepUp.toStringAsFixed(1)}% / yr',
                tokens,
              ),
              Slider(
                value: _annualStepUp,
                min: 0.0,
                max: 20.0,
                divisions: 40,
                activeColor: tokens.accent,
                inactiveColor: tokens.borderSubtle,
                onChanged: (val) {
                  setState(() {
                    _annualStepUp = double.parse(val.toStringAsFixed(1));
                    _stepUpController.text = _annualStepUp.toString();
                  });
                },
              ),
              _buildTextInputField(
                controller: _stepUpController,
                onChanged: (text) {
                  final val = double.tryParse(text);
                  if (val != null) {
                    setState(() => _annualStepUp = val.clamp(0.0, 50.0));
                  }
                },
                tokens: tokens,
                suffix: '% increase annually',
              ),
              const SizedBox(height: 20),

              // Monthly Extra Payment
              _buildInputLabelRow(
                'Monthly Extra Payment',
                _formatCurrency(_extraMonthly),
                tokens,
              ),
              Slider(
                value: _extraMonthly.clamp(0.0, 100000.0),
                min: 0.0,
                max: 100000.0,
                divisions: 100,
                activeColor: tokens.accent,
                inactiveColor: tokens.borderSubtle,
                onChanged: (val) {
                  setState(() {
                    _extraMonthly = val;
                    _extraMonthlyController.text = val.round().toString();
                  });
                },
              ),
              _buildTextInputField(
                controller: _extraMonthlyController,
                onChanged: (text) {
                  final val = double.tryParse(text);
                  if (val != null) {
                    setState(() => _extraMonthly = val.clamp(0.0, 1000000.0));
                  }
                },
                tokens: tokens,
                suffix: 'Extra monthly payment',
              ),
              const SizedBox(height: 20),

              // Lump Sum Amount
              _buildInputLabelRow(
                'One-Time Lump Sum Payment',
                _formatCurrency(_lumpSumAmount),
                tokens,
              ),
              Slider(
                value: _lumpSumAmount.clamp(0.0, 500000.0),
                min: 0.0,
                max: 500000.0,
                divisions: 100,
                activeColor: tokens.accent,
                inactiveColor: tokens.borderSubtle,
                onChanged: (val) {
                  setState(() {
                    _lumpSumAmount = val;
                    _lumpSumAmountController.text = val.round().toString();
                  });
                },
              ),
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildTextInputField(
                      controller: _lumpSumAmountController,
                      onChanged: (text) {
                        final val = double.tryParse(text);
                        if (val != null) {
                          setState(() => _lumpSumAmount = val.clamp(0.0, _principal));
                        }
                      },
                      tokens: tokens,
                      suffix: 'Amount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: _buildTextInputField(
                      controller: _lumpSumMonthController,
                      onChanged: (text) {
                        final val = int.tryParse(text);
                        if (val != null) {
                          setState(() => _lumpSumMonth = val.clamp(1, 240));
                        }
                      },
                      tokens: tokens,
                      suffix: 'Month #',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Inputs Helpers ──

  Widget _buildInputLabelRow(String label, String value, ThemeTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.accent)),
      ],
    );
  }

  Widget _buildTextInputField({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required ThemeTokens tokens,
    required String suffix,
  }) {
    return Container(
      height: 32,
      margin: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        style: TextStyle(color: tokens.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          suffixText: suffix,
          suffixStyle: TextStyle(color: tokens.textMuted, fontSize: 9),
          filled: true,
          fillColor: tokens.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTabButton(String mode, String label, ThemeTokens tokens) {
    final isSelected = _calcMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _calcMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? tokens.textPrimary : tokens.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Results Panel Layout ──

  Widget _buildResultsPanel({
    required ThemeTokens tokens,
    required SimulationResult baseline,
    required SimulationResult accelerated,
    required double interestSavings,
    required int monthsSaved,
    required bool hasInfiniteDebt,
    required double baseEmi,
  }) {
    if (hasInfiniteDebt) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderSubtle),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 40, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            Text(
              'Infinite Debt Growth Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your monthly payment is too low. It does not cover the monthly interest accrued, causing your loan balance to grow indefinitely. Please increase your monthly repayment amount or reduce the interest rate.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Acceleration Summary Row ──
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL INTEREST SAVED',
                  value: _formatCurrency(interestSavings),
                  color: const Color(0xFF10B981), // Green
                  tokens: tokens,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'TIME SAVED',
                  value: _formatMonthsToYearsAndMonths(monthsSaved),
                  color: tokens.accent,
                  tokens: tokens,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Output Tabs Selection
          Row(
            children: [
              _buildOutputTabButton('summary', 'Repayment Summary', tokens),
              const SizedBox(width: 16),
              _buildOutputTabButton('schedule', 'Amortization Table', tokens),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Projections
          Expanded(
            child: _outputTab == 'summary'
                ? _buildSummaryView(tokens, baseline, accelerated, baseEmi)
                : _buildScheduleView(tokens, baseline, accelerated),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required ThemeTokens tokens,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tokens.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputTabButton(String tab, String label, ThemeTokens tokens) {
    final isSelected = _outputTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _outputTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? tokens.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? tokens.textPrimary : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Summary tab view ──

  Widget _buildSummaryView(
    ThemeTokens tokens,
    SimulationResult baseline,
    SimulationResult accelerated,
    double baseEmi,
  ) {
    return Column(
      children: [
        // Side-by-Side Comparison
        Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: tokens.borderSubtle, width: 0.5),
          ),
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(3),
          },
          children: [
            TableRow(
              children: [
                _buildTableCell('Metric', tokens, isHeader: true),
                _buildTableCell('Standard Payoff', tokens, isHeader: true),
                _buildTableCell('Accelerated Payoff', tokens, isHeader: true, headerColor: tokens.accent),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Initial Debt Principal', tokens),
                _buildTableCell(_formatCurrency(_principal), tokens),
                _buildTableCell(_formatCurrency(_principal), tokens),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Initial Monthly EMI', tokens),
                _buildTableCell(_formatCurrency(baseEmi), tokens),
                _buildTableCell('${_formatCurrency(baseEmi + _extraMonthly)}*', tokens),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Total Repayment Time', tokens),
                _buildTableCell(_formatMonthsToYearsAndMonths(baseline.totalMonths), tokens),
                _buildTableCell(_formatMonthsToYearsAndMonths(accelerated.totalMonths), tokens, valueColor: const Color(0xFF10B981)),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Total Interest Cost', tokens),
                _buildTableCell(_formatCurrency(baseline.totalInterest), tokens),
                _buildTableCell(_formatCurrency(accelerated.totalInterest), tokens, valueColor: const Color(0xFF10B981)),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Total Cost (Principal + Interest)', tokens),
                _buildTableCell(_formatCurrency(baseline.totalPaid), tokens),
                _buildTableCell(_formatCurrency(accelerated.totalPaid), tokens),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '*Includes monthly extra payment. Accelerated monthly payment increases by ${_annualStepUp.toStringAsFixed(1)}% every 12 months.',
            style: TextStyle(fontSize: 9, color: tokens.textMuted, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 24),

        // Visual Debt Paydown Chart
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DEBT BALANCE PROJECTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textSecondary)),
                  Row(
                    children: [
                      _buildChartLegendItem('Standard', const Color(0xFFEF4444)), // Red
                      const SizedBox(width: 14),
                      _buildChartLegendItem('Accelerated', tokens.accent), // Teal/Blue
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: DebtTrendPainter(
                        baselineTrend: baseline.monthlyBalances,
                        acceleratedTrend: accelerated.monthlyBalances,
                        baselineColor: const Color(0xFFEF4444),
                        acceleratedColor: tokens.accent,
                        gridColor: tokens.borderSubtle,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text,
    ThemeTokens tokens, {
    bool isHeader = false,
    Color? headerColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.left : TextAlign.left,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: headerColor ?? valueColor ?? (isHeader ? tokens.textSecondary : tokens.textPrimary),
        ),
      ),
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── Amortization Table Tab view ──

  Widget _buildScheduleView(ThemeTokens tokens, SimulationResult baseline, SimulationResult accelerated) {
    final maxYears = max(baseline.yearlyProjections.length, accelerated.yearlyProjections.length);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: maxYears + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          // Table Headers
          return Table(
            border: TableBorder(bottom: BorderSide(color: tokens.borderMedium, width: 1)),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(4),
              2: FlexColumnWidth(4),
            },
            children: [
              TableRow(
                children: [
                  _buildTableCell('Year', tokens, isHeader: true),
                  _buildTableCell('Standard Balance', tokens, isHeader: true),
                  _buildTableCell('Accelerated Balance', tokens, isHeader: true, headerColor: tokens.accent),
                ],
              ),
            ],
          );
        }

        final yearIdx = index - 1;
        final baseProj = yearIdx < baseline.yearlyProjections.length ? baseline.yearlyProjections[yearIdx] : null;
        final accelProj = yearIdx < accelerated.yearlyProjections.length ? accelerated.yearlyProjections[yearIdx] : null;

        return Table(
          border: TableBorder(horizontalInside: BorderSide(color: tokens.borderSubtle, width: 0.5)),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(4),
            2: FlexColumnWidth(4),
          },
          children: [
            TableRow(
              children: [
                _buildTableCell('Yr ${yearIdx + 1}', tokens),
                _buildTableCell(baseProj != null ? _formatCurrency(baseProj.remainingBalance) : 'Paid Off', tokens),
                _buildTableCell(
                  accelProj != null ? _formatCurrency(accelProj.remainingBalance) : 'Paid Off',
                  tokens,
                  valueColor: accelProj == null ? const Color(0xFF10B981) : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
