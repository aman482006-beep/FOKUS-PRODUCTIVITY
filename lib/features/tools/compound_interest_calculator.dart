import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';

class CompoundInterestCalculatorPage extends StatefulWidget {
  final VoidCallback onBack;

  const CompoundInterestCalculatorPage({super.key, required this.onBack});

  @override
  State<CompoundInterestCalculatorPage> createState() => _CompoundInterestCalculatorPageState();
}

class _CompoundInterestCalculatorPageState extends State<CompoundInterestCalculatorPage> {
  double _initialPrincipal = 100000; // 1 Lakh default
  double _monthlyContribution = 5000;
  double _annualRate = 10.0;
  int _years = 10;
  int _compoundFrequency = 12; // Monthly compounding default
  String _currency = 'INR';

  late TextEditingController _principalController;
  late TextEditingController _contributionController;
  late TextEditingController _rateController;
  late TextEditingController _yearsController;

  String get _currencySymbol => _currency == 'INR' ? '₹' : r'$';

  String _outputTab = 'summary'; // 'summary' or 'projections'

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _principalController = TextEditingController(text: _initialPrincipal.round().toString());
    _contributionController = TextEditingController(text: _monthlyContribution.round().toString());
    _rateController = TextEditingController(text: _annualRate.toString());
    _yearsController = TextEditingController(text: _years.toString());
  }

  @override
  void dispose() {
    _principalController.dispose();
    _contributionController.dispose();
    _rateController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  void _onSliderPrincipalChanged(double value) {
    setState(() {
      _initialPrincipal = value;
      _principalController.text = value.round().toString();
    });
  }

  void _onTextPrincipalChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _initialPrincipal = val.clamp(1000, 50000000);
      });
    }
  }

  void _onSliderContributionChanged(double value) {
    setState(() {
      _monthlyContribution = value;
      _contributionController.text = value.round().toString();
    });
  }

  void _onTextContributionChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _monthlyContribution = val.clamp(0, 1000000);
      });
    }
  }

  void _onSliderRateChanged(double value) {
    setState(() {
      _annualRate = double.parse(value.toStringAsFixed(1));
      _rateController.text = _annualRate.toString();
    });
  }

  void _onTextRateChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _annualRate = val.clamp(1.0, 30.0);
      });
    }
  }

  void _onSliderYearsChanged(double value) {
    setState(() {
      _years = value.round();
      _yearsController.text = _years.toString();
    });
  }

  void _onTextYearsChanged(String text) {
    final val = int.tryParse(text);
    if (val != null) {
      setState(() {
        _years = val.clamp(1, 50);
      });
    }
  }

  void _sanitizeInputs() {
    setState(() {
      _principalController.text = _initialPrincipal.round().toString();
      _contributionController.text = _monthlyContribution.round().toString();
      _rateController.text = _annualRate.toString();
      _yearsController.text = _years.toString();
    });
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('compound_currency');
    if (saved != null) setState(() => _currency = saved);
  }

  Future<void> _saveCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('compound_currency', _currency);
  }

  String _formatCurrency(double value) {
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

  // Calculation function for growth at a given year
  (double totalInvested, double totalValue, double totalInterest) _calculateGrowth(int year) {
    final r = _annualRate / 100;
    final n = _compoundFrequency;
    final t = year;

    // Monthly compounding equivalent rate
    final monthlyRate = pow(1 + r / n, n / 12) - 1;
    final totalMonths = t * 12;

    final principalFV = _initialPrincipal * pow(1 + monthlyRate, totalMonths);
    double contributionsFV = 0;
    if (monthlyRate > 0) {
      contributionsFV = _monthlyContribution *
          ((pow(1 + monthlyRate, totalMonths) - 1) / monthlyRate);
    } else {
      contributionsFV = _monthlyContribution * totalMonths;
    }

    final totalValue = principalFV + contributionsFV;
    final totalInvested = _initialPrincipal + (_monthlyContribution * totalMonths);
    final totalInterest = max(0.0, totalValue - totalInvested);

    return (totalInvested, totalValue, totalInterest);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    // Calculate current values
    final (totalInvested, totalValue, totalInterest) = _calculateGrowth(_years);
    final principalFraction = totalValue > 0 ? (totalInvested / totalValue) : 1.0;

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: tokens.textPrimary),
                  onPressed: widget.onBack,
                  splashRadius: 20,
                  tooltip: 'Back to Tools',
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compound Interest Calculator',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calculate initial principal growth with compound interest and recurring contributions',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                // Currency Toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _currencyTab('INR', '₹', tokens),
                      const SizedBox(width: 2),
                      _currencyTab('USD', r'$', tokens),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Main Content Layout
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left Side (Inputs) ──
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus) _sanitizeInputs();
                        },
                        child: Column(
                          children: [
                            // Initial Principal Card
                            _inputCard(
                              title: 'Initial Principal',
                              controller: _principalController,
                              prefix: _currencySymbol,
                              suffix: '',
                              min: 1000,
                              max: 5000000,
                              value: _initialPrincipal,
                              onSliderChanged: _onSliderPrincipalChanged,
                              onTextChanged: _onTextPrincipalChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Monthly Contribution Card
                            _inputCard(
                              title: 'Monthly Contribution',
                              controller: _contributionController,
                              prefix: _currencySymbol,
                              suffix: '',
                              min: 0,
                              max: 100000,
                              value: _monthlyContribution,
                              onSliderChanged: _onSliderContributionChanged,
                              onTextChanged: _onTextContributionChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Interest Rate Card
                            _inputCard(
                              title: 'Annual Interest Rate',
                              controller: _rateController,
                              prefix: '',
                              suffix: '%',
                              min: 1.0,
                              max: 25.0,
                              value: _annualRate,
                              onSliderChanged: _onSliderRateChanged,
                              onTextChanged: _onTextRateChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Years & Compound Interval Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Years Input
                                Expanded(
                                  child: _inputCard(
                                    title: 'Years to Grow',
                                    controller: _yearsController,
                                    prefix: '',
                                    suffix: 'Yr',
                                    min: 1.0,
                                    max: 50.0,
                                    value: _years.toDouble(),
                                    onSliderChanged: _onSliderYearsChanged,
                                    onTextChanged: _onTextYearsChanged,
                                    tokens: tokens,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Compound Frequency Dropdown
                                Container(
                                  width: 180,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: tokens.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.borderSubtle),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Compounded',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: tokens.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _compoundFrequency,
                                          dropdownColor: tokens.surface,
                                          icon: Icon(Icons.arrow_drop_down, color: tokens.textSecondary),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.textPrimary,
                                          ),
                                          isDense: true,
                                          isExpanded: true,
                                          items: const [
                                            DropdownMenuItem(value: 12, child: Text('Monthly')),
                                            DropdownMenuItem(value: 4, child: Text('Quarterly')),
                                            DropdownMenuItem(value: 2, child: Text('Semi-Annually')),
                                            DropdownMenuItem(value: 1, child: Text('Annually')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _compoundFrequency = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // ── Right Side (Outputs/Projections Tabs) ──
                  Expanded(
                    flex: 3,
                    child: PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Tabs Selector
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: tokens.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              children: [
                                _tabToggle(
                                  label: 'Summary',
                                  active: _outputTab == 'summary',
                                  onTap: () => setState(() => _outputTab = 'summary'),
                                  tokens: tokens,
                                ),
                                _tabToggle(
                                  label: 'Projections',
                                  active: _outputTab == 'projections',
                                  onTap: () => setState(() => _outputTab = 'projections'),
                                  tokens: tokens,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Tab Content
                          Expanded(
                            child: _outputTab == 'summary'
                                ? _buildSummaryView(tokens, totalInvested, totalValue, totalInterest, principalFraction)
                                : _buildProjectionsView(tokens),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currencyTab(String code, String symbol, ThemeTokens tokens) {
    final active = _currency == code;
    return GestureDetector(
      onTap: () {
        setState(() => _currency = code);
        _saveCurrency();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$symbol $code',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? tokens.accent : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _tabToggle({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required ThemeTokens tokens,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? tokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.safeWithOpacity(0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? tokens.textPrimary : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView(
    ThemeTokens tokens,
    double totalInvested,
    double totalValue,
    double totalInterest,
    double principalFraction,
  ) {
    return Column(
      children: [
        // Donut Chart + Center Value
        SizedBox(
          height: 140,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(140, 140),
                painter: _DonutPainter(
                  investedFraction: principalFraction,
                  investedColor: tokens.accent,
                  returnsColor: const Color(0xFFF59E0B), // Amber
                  backgroundColor: tokens.borderSubtle,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'End Balance',
                    style: TextStyle(
                      fontSize: 9,
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(totalValue),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Outputs
        _outputRow(
          label: 'Total Invested',
          value: _formatCurrency(totalInvested),
          dotColor: tokens.accent,
          tokens: tokens,
        ),
        const SizedBox(height: 12),
        _outputRow(
          label: 'Interest Earned',
          value: _formatCurrency(totalInterest),
          dotColor: const Color(0xFFF59E0B),
          tokens: tokens,
        ),
        const Divider(height: 24),
        _outputRow(
          label: 'Future Wealth',
          value: _formatCurrency(totalValue),
          dotColor: Colors.transparent,
          isBold: true,
          tokens: tokens,
        ),
      ],
    );
  }

  Widget _buildProjectionsView(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Headers
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                'Year',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textMuted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Invested',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textMuted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Balance',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textMuted),
                textAlign: Alignment.centerRight.horizontalDependency, // align right
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Table Rows List
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _years,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final year = index + 1;
              final (invested, balance, _) = _calculateGrowth(year);
              return Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Yr $year',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCurrency(invested),
                      style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCurrency(balance),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _inputCard({
    required String title,
    required TextEditingController controller,
    required String prefix,
    required String suffix,
    required double min,
    required double max,
    required double value,
    required ValueChanged<double> onSliderChanged,
    required ValueChanged<String> onTextChanged,
    required ThemeTokens tokens,
  }) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
              ),
              // Numeric manual input
              Container(
                width: 120,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    if (prefix.isNotEmpty)
                      Text(
                        prefix,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted),
                      ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: onTextChanged,
                        onSubmitted: (_) => _sanitizeInputs(),
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          suffix,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tokens.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: tokens.accent,
              inactiveTrackColor: tokens.borderSubtle,
              thumbColor: tokens.accent,
              overlayColor: tokens.accent.safeWithOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onSliderChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outputRow({
    required String label,
    required String value,
    required Color dotColor,
    bool isBold = false,
    required ThemeTokens tokens,
  }) {
    return Row(
      children: [
        if (dotColor != Colors.transparent) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: isBold ? tokens.textPrimary : tokens.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double investedFraction;
  final Color investedColor;
  final Color returnsColor;
  final Color backgroundColor;

  _DonutPainter({
    required this.investedFraction,
    required this.investedColor,
    required this.returnsColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - paint.strokeWidth / 2;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    if (investedFraction >= 1.0) {
      paint.color = investedColor;
      canvas.drawCircle(center, radius, paint);
      return;
    } else if (investedFraction <= 0.0) {
      paint.color = returnsColor;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final sweepAngleInvested = 2 * pi * investedFraction;
    paint.color = investedColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngleInvested,
      false,
      paint,
    );

    final sweepAngleReturns = 2 * pi * (1.0 - investedFraction);
    paint.color = returnsColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + sweepAngleInvested,
      sweepAngleReturns,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.investedFraction != investedFraction ||
        oldDelegate.investedColor != investedColor ||
        oldDelegate.returnsColor != returnsColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

// Simple helper to align text right in projections header
extension AlignmentHelpers on Alignment {
  TextAlign get horizontalDependency {
    if (x > 0) return TextAlign.right;
    if (x < 0) return TextAlign.left;
    return TextAlign.center;
  }
}
