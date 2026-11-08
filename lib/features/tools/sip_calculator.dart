import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';

class SipCalculatorPage extends StatefulWidget {
  final VoidCallback onBack;

  const SipCalculatorPage({super.key, required this.onBack});

  @override
  State<SipCalculatorPage> createState() => _SipCalculatorPageState();
}

class _SipCalculatorPageState extends State<SipCalculatorPage> {
  double _monthlyInvestment = 5000;
  double _expectedReturn = 12.0;
  int _years = 10;
  String _currency = 'INR';
  bool _adjustForInflation = false;
  double _inflationRate = 6.0;

  late TextEditingController _investmentController;
  late TextEditingController _returnController;
  late TextEditingController _yearsController;
  late TextEditingController _inflationController;

  String get _currencySymbol => _currency == 'INR' ? '₹' : r'$';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _investmentController = TextEditingController(text: _monthlyInvestment.round().toString());
    _returnController = TextEditingController(text: _expectedReturn.toString());
    _yearsController = TextEditingController(text: _years.toString());
    _inflationController = TextEditingController(text: _inflationRate.toString());
  }

  @override
  void dispose() {
    _investmentController.dispose();
    _returnController.dispose();
    _yearsController.dispose();
    _inflationController.dispose();
    super.dispose();
  }

  void _onSliderInvestmentChanged(double value) {
    setState(() {
      _monthlyInvestment = value;
      _investmentController.text = value.round().toString();
    });
  }

  void _onTextInvestmentChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _monthlyInvestment = val.clamp(500, 1000000);
      });
    }
  }

  void _onSliderReturnChanged(double value) {
    setState(() {
      _expectedReturn = double.parse(value.toStringAsFixed(1));
      _returnController.text = _expectedReturn.toString();
    });
  }

  void _onTextReturnChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _expectedReturn = val.clamp(1.0, 30.0);
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
        _years = val.clamp(1, 40);
      });
    }
  }

  void _onSliderInflationChanged(double value) {
    setState(() {
      _inflationRate = double.parse(value.toStringAsFixed(1));
      _inflationController.text = _inflationRate.toString();
    });
  }

  void _onTextInflationChanged(String text) {
    final val = double.tryParse(text);
    if (val != null) {
      setState(() {
        _inflationRate = val.clamp(1.0, 15.0);
      });
    }
  }

  // Restore bounds on submission or focus loss
  void _sanitizeInputs() {
    setState(() {
      _investmentController.text = _monthlyInvestment.round().toString();
      _returnController.text = _expectedReturn.toString();
      _yearsController.text = _years.toString();
      _inflationController.text = _inflationRate.toString();
    });
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sip_currency');
    if (saved != null) setState(() => _currency = saved);
  }

  Future<void> _saveCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sip_currency', _currency);
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

    // Calculate SIP outputs
    final monthlyRate = (_expectedReturn / 100) / 12;
    final totalMonths = _years * 12;
    final nominalInvested = _monthlyInvestment * totalMonths;

    double nominalFutureValue = 0;
    if (monthlyRate > 0) {
      nominalFutureValue = _monthlyInvestment *
          ((pow(1 + monthlyRate, totalMonths) - 1) / monthlyRate) *
          (1 + monthlyRate);
    } else {
      nominalFutureValue = nominalInvested;
    }

    final double discountFactor = _adjustForInflation
        ? pow(1 + (_inflationRate / 100), -_years).toDouble()
        : 1.0;

    final totalValue = nominalFutureValue * discountFactor;
    final totalInvested = nominalInvested * discountFactor;
    final estReturns = max(0.0, totalValue - totalInvested);

    final investedFraction = totalValue > 0 ? (totalInvested / totalValue) : 1.0;

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Back Button
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
                      'SIP Calculator',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calculate growth of your monthly mutual fund investments',
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

            // Content Area split into Input (Left) and Output (Right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left Panel (Inputs) ──
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
                            // Monthly Investment Input
                            _inputCard(
                              title: 'Monthly Investment',
                              controller: _investmentController,
                              prefix: _currencySymbol,
                              suffix: '',
                              min: 500,
                              max: 1000000,
                              value: _monthlyInvestment,
                              onSliderChanged: _onSliderInvestmentChanged,
                              onTextChanged: _onTextInvestmentChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Expected Return Rate Input
                            _inputCard(
                              title: 'Expected Return Rate (p.a.)',
                              controller: _returnController,
                              prefix: '',
                              suffix: '%',
                              min: 1.0,
                              max: 30.0,
                              value: _expectedReturn,
                              onSliderChanged: _onSliderReturnChanged,
                              onTextChanged: _onTextReturnChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Tenure Input
                            _inputCard(
                              title: 'Time Period (Years)',
                              controller: _yearsController,
                              prefix: '',
                              suffix: 'Yr',
                              min: 1.0,
                              max: 40.0,
                              value: _years.toDouble(),
                              onSliderChanged: _onSliderYearsChanged,
                              onTextChanged: _onTextYearsChanged,
                              tokens: tokens,
                            ),
                            const SizedBox(height: 16),

                            // Adjust for Inflation Card
                            PremiumCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _adjustForInflation = !_adjustForInflation;
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.trending_down_rounded,
                                          size: 18,
                                          color: _adjustForInflation
                                              ? tokens.accent
                                              : tokens.textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Adjust for Inflation',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                        const Spacer(),
                                        motion.PremiumToggle(
                                          value: _adjustForInflation,
                                          onChanged: (val) {
                                            setState(() {
                                              _adjustForInflation = val;
                                            });
                                          },
                                          activeColor: tokens.accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: motion.PremiumDurations.panelSlide,
                                    curve: motion.PremiumCurves.easeOutCubic,
                                    child: Container(
                                      key: const ValueKey('inflation_expandable_container'),
                                      child: _adjustForInflation
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 16),
                                                const Divider(height: 1),
                                                const SizedBox(height: 16),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Expected Inflation Rate (p.a.)',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: tokens.textSecondary,
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 120,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: tokens.background,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                            color: tokens.borderSubtle),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                    alignment: Alignment.center,
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: TextField(
                                                            controller: _inflationController,
                                                            keyboardType:
                                                                const TextInputType
                                                                    .numberWithOptions(
                                                                    decimal: true),
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter
                                                                  .allow(RegExp(
                                                                      r'^\d*\.?\d*')),
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
                                                              contentPadding:
                                                                  EdgeInsets.zero,
                                                            ),
                                                            onChanged:
                                                                _onTextInflationChanged,
                                                            onSubmitted: (_) =>
                                                                _sanitizeInputs(),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(
                                                              left: 4),
                                                          child: Text(
                                                            '%',
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight.w600,
                                                                color: tokens.textMuted),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              SliderTheme(
                                                data: SliderThemeData(
                                                  trackHeight: 3,
                                                  activeTrackColor: tokens.accent,
                                                  inactiveTrackColor: tokens.borderSubtle,
                                                  thumbColor: tokens.accent,
                                                  overlayColor: tokens.accent
                                                      .safeWithOpacity(0.1),
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                          enabledThumbRadius: 6),
                                                ),
                                                child: Slider(
                                                  value: _inflationRate.clamp(1.0, 15.0),
                                                  min: 1.0,
                                                  max: 15.0,
                                                  onChanged: _onSliderInflationChanged,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
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

                  // ── Right Panel (Visual Breakdown & Outputs) ──
                  Expanded(
                    flex: 3,
                    child: PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _adjustForInflation
                                ? 'Investment Summary (Inflation Adj.)'
                                : 'Investment Summary',
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
                                    investedFraction: investedFraction,
                                    investedColor: tokens.accent,
                                    returnsColor: const Color(0xFF10B981), // Emerald Green
                                    backgroundColor: tokens.borderSubtle,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _adjustForInflation ? "Today's Value" : 'Total Value',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tokens.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatCurrency(totalValue),
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

                          // Output Cards
                          _outputRow(
                            label: _adjustForInflation
                                ? 'Invested (Today\'s Value)'
                                : 'Invested Amount',
                            value: _formatCurrency(totalInvested),
                            dotColor: tokens.accent,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 12),
                          _outputRow(
                            label: _adjustForInflation
                                ? 'Est. Returns (Adj.)'
                                : 'Est. Returns',
                            value: _formatCurrency(estReturns),
                            dotColor: const Color(0xFF10B981),
                            tokens: tokens,
                          ),
                          const Divider(height: 24),
                          _outputRow(
                            label: _adjustForInflation
                                ? 'Today\'s Value'
                                : 'Total Value',
                            value: _formatCurrency(totalValue),
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
              // Manual Input Box
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
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

    // Background track
    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    // If fraction is full or zero, draw complete circle
    if (investedFraction >= 1.0) {
      paint.color = investedColor;
      canvas.drawCircle(center, radius, paint);
      return;
    } else if (investedFraction <= 0.0) {
      paint.color = returnsColor;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Invested Arc
    final sweepAngleInvested = 2 * pi * investedFraction;
    paint.color = investedColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngleInvested,
      false,
      paint,
    );

    // Returns Arc
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
