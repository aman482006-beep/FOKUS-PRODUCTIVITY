import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';

class EmiCalculatorPage extends StatefulWidget {
  final VoidCallback onBack;

  const EmiCalculatorPage({super.key, required this.onBack});

  @override
  State<EmiCalculatorPage> createState() => _EmiCalculatorPageState();
}

class _EmiCalculatorPageState extends State<EmiCalculatorPage> {
  double _loanAmount = 1000000; // 10 Lakhs default
  double _interestRate = 8.5;
  int _tenure = 120; // Months default
  bool _isYears = true; // Years mode toggle
  String _currency = 'INR';

  late TextEditingController _amountController;
  late TextEditingController _rateController;
  late TextEditingController _tenureController;

  String get _currencySymbol => _currency == 'INR' ? '₹' : r'$';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _amountController = TextEditingController(text: _loanAmount.round().toString());
    _rateController = TextEditingController(text: _interestRate.toString());
    _tenureController = TextEditingController(text: (_isYears ? (_tenure / 12).round() : _tenure).toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _onSliderAmountChanged(double value) {
    setState(() {
      _loanAmount = value;
      _amountController.text = value.round().toString();
    });
  }

  void _onTextAmountChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _loanAmount = val.clamp(10000, 100000000);
      });
    }
  }

  void _onSliderRateChanged(double value) {
    setState(() {
      _interestRate = double.parse(value.toStringAsFixed(2));
      _rateController.text = _interestRate.toString();
    });
  }

  void _onTextRateChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _interestRate = val.clamp(1.0, 30.0);
      });
    }
  }

  void _onSliderTenureChanged(double value) {
    setState(() {
      if (_isYears) {
        final yrs = value.round();
        _tenure = yrs * 12;
        _tenureController.text = yrs.toString();
      } else {
        _tenure = value.round();
        _tenureController.text = _tenure.toString();
      }
    });
  }

  void _onTextTenureChanged(String text) {
    final val = int.tryParse(text);
    if (val != null) {
      setState(() {
        if (_isYears) {
          final clampedYrs = val.clamp(1, 40);
          _tenure = clampedYrs * 12;
        } else {
          _tenure = val.clamp(6, 480);
        }
      });
    }
  }

  void _toggleTenureUnit(bool toYears) {
    if (_isYears == toYears) return;
    setState(() {
      _isYears = toYears;
      if (_isYears) {
        // Convert months to years
        final yrs = (_tenure / 12).round().clamp(1, 40);
        _tenure = yrs * 12;
        _tenureController.text = yrs.toString();
      } else {
        // Keep tenure in months
        _tenure = _tenure.clamp(6, 480);
        _tenureController.text = _tenure.toString();
      }
    });
  }

  void _sanitizeInputs() {
    setState(() {
      _amountController.text = _loanAmount.round().toString();
      _rateController.text = _interestRate.toString();
      _tenureController.text = (_isYears ? (_tenure / 12).round() : _tenure).toString();
    });
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('emi_currency');
    if (saved != null) setState(() => _currency = saved);
  }

  Future<void> _saveCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emi_currency', _currency);
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

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    // Calculate EMI
    final r = (_interestRate / 100) / 12;
    final n = _tenure;
    final p = _loanAmount;

    double emi = 0;
    if (r > 0) {
      emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    } else {
      emi = p / n;
    }

    final totalPayable = emi * n;
    final totalInterest = max(0.0, totalPayable - p);
    final principalFraction = totalPayable > 0 ? (p / totalPayable) : 1.0;

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
                      'EMI Calculator',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calculate loan monthly repayments, interest, and total payable amount',
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
                            // Loan Amount Card
                            _inputCard(
                              title: 'Loan Amount',
                              controller: _amountController,
                              prefix: _currencySymbol,
                              suffix: '',
                              min: 10000,
                              max: 10000000, // 1 Crore
                              value: _loanAmount,
                              onSliderChanged: _onSliderAmountChanged,
                              onTextChanged: _onTextAmountChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Interest Rate Card
                            _inputCard(
                              title: 'Interest Rate (p.a.)',
                              controller: _rateController,
                              prefix: '',
                              suffix: '%',
                              min: 5.0,
                              max: 20.0,
                              value: _interestRate,
                              onSliderChanged: _onSliderRateChanged,
                              onTextChanged: _onTextRateChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Loan Tenure Card with Toggle
                            PremiumCard(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Loan Tenure',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                      // Toggle Button (Years / Months)
                                      Row(
                                        children: [
                                          Container(
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: tokens.background,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: tokens.borderSubtle),
                                            ),
                                            padding: const EdgeInsets.all(2),
                                            child: Row(
                                              children: [
                                                _toggleButton(
                                                  label: 'Yr',
                                                  active: _isYears,
                                                  onTap: () => _toggleTenureUnit(true),
                                                  tokens: tokens,
                                                ),
                                                _toggleButton(
                                                  label: 'Mo',
                                                  active: !_isYears,
                                                  onTap: () => _toggleTenureUnit(false),
                                                  tokens: tokens,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Text input
                                          Container(
                                            width: 80,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: tokens.background,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: tokens.borderSubtle),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            alignment: Alignment.center,
                                            child: TextField(
                                              controller: _tenureController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
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
                                              onChanged: _onTextTenureChanged,
                                              onSubmitted: (_) => _sanitizeInputs(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Tenure Slider
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
                                      value: (_isYears ? (_tenure / 12) : _tenure.toDouble()).clamp(
                                        _isYears ? 1.0 : 6.0,
                                        _isYears ? 30.0 : 360.0,
                                      ),
                                      min: _isYears ? 1.0 : 6.0,
                                      max: _isYears ? 30.0 : 360.0,
                                      onChanged: _onSliderTenureChanged,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // ── Right Side (Outputs Summary) ──
                  Expanded(
                    flex: 3,
                    child: PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Repayment Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 24),

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
                                    returnsColor: const Color(0xFF3B82F6), // Blue
                                    backgroundColor: tokens.borderSubtle,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Monthly EMI',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: tokens.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatCurrency(emi),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Details Rows
                          _outputRow(
                            label: 'Principal Amount',
                            value: _formatCurrency(_loanAmount),
                            dotColor: tokens.accent,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 12),
                          _outputRow(
                            label: 'Interest Payable',
                            value: _formatCurrency(totalInterest),
                            dotColor: const Color(0xFF3B82F6),
                            tokens: tokens,
                          ),
                          const Divider(height: 24),
                          _outputRow(
                            label: 'Total Payment',
                            value: _formatCurrency(totalPayable),
                            dotColor: Colors.transparent,
                            isBold: true,
                            tokens: tokens,
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

  Widget _toggleButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required ThemeTokens tokens,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.safeWithOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? tokens.textPrimary : tokens.textMuted,
          ),
        ),
      ),
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
              // Numeric manual input field
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
