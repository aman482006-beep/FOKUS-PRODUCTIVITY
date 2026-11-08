import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';

// ──────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────

class InflationCalculatorPage extends StatefulWidget {
  final VoidCallback onBack;
  const InflationCalculatorPage({super.key, required this.onBack});

  @override
  State<InflationCalculatorPage> createState() => _InflationCalculatorPageState();
}

class _InflationCalculatorPageState extends State<InflationCalculatorPage> {
  double _amount = 10000;
  double _inflationRate = 6.0;
  double _years = 10;
  String _currency = 'USD';

  String get _currencySymbol => _currency == 'INR' ? '₹' : r'$';

  List<_YearData> get _yearBreakdown {
    final list = <_YearData>[];
    for (int i = 0; i <= _years.round(); i++) {
      final year = i;
      final factor = 1 / _pow(1 + _inflationRate / 100, year);
      final futureValue = _amount * factor;
      final loss = _amount - futureValue;
      list.add(_YearData(year: year, futureValue: futureValue, loss: loss));
    }
    return list;
  }

  double get _purchasingPower => _yearBreakdown.last.futureValue;
  double get _totalLoss => _amount - _purchasingPower;
  double get _lossPercent => _amount > 0 ? (_totalLoss / _amount) * 100 : 0;

  double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('inflation_currency');
    if (saved != null) setState(() => _currency = saved);
  }

  Future<void> _saveCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inflation_currency', _currency);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final data = _yearBreakdown;

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
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: tokens.textPrimary), onPressed: widget.onBack, splashRadius: 20, tooltip: 'Back'),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inflation Impact Calculator', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: tokens.textPrimary, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('See how inflation erodes your money over time', style: TextStyle(fontSize: 13, color: tokens.textMuted)),
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
            const SizedBox(height: 20),

            // Main content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Controls Panel
                  SizedBox(
                    width: 320,
                    child: PremiumCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Parameters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary, letterSpacing: 0.3)),
                          const SizedBox(height: 20),

                          _sliderInput(
                            tokens: tokens,
                            label: 'Current Amount',
                            value: _amount,
                            min: 100,
                            max: 10000000,
                            step: 100,
                            prefix: _currencySymbol,
                            format: (v) => '$_currencySymbol${_fmtCurrency(v)}',
                            onChanged: (v) => setState(() => _amount = v),
                          ),
                          const SizedBox(height: 20),

                          _sliderInput(
                            tokens: tokens,
                            label: 'Inflation Rate',
                            value: _inflationRate,
                            min: 0,
                            max: 30,
                            step: 0.1,
                            suffix: '%',
                            format: (v) => '${v.toStringAsFixed(1)}%',
                            onChanged: (v) => setState(() => _inflationRate = v),
                          ),

                          // Inflation rate indicators
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                _indicator('Low', 2, tokens),
                                const Spacer(),
                                _indicator('Avg', 6, tokens),
                                const Spacer(),
                                _indicator('High', 15, tokens),
                                const Spacer(),
                                _indicator('Crisis', 25, tokens),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          _sliderInput(
                            tokens: tokens,
                            label: 'Time Period',
                            value: _years,
                            min: 1,
                            max: 50,
                            step: 1,
                            format: (v) => '${v.round()} years',
                            onChanged: (v) => setState(() => _years = v),
                          ),

                          const SizedBox(height: 24),

                          // Impact Summary
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEF4444).withValues(alpha: 0.08),
                                  const Color(0xFFEF4444).withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.15)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 16, color: const Color(0xFFEF4444)),
                                    const SizedBox(width: 6),
                                    Text('Inflation Impact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _impactRow('Original Value', '$_currencySymbol${_fmtCurrency(_amount)}', tokens.textPrimary, tokens),
                                _impactRow('Future Value', '$_currencySymbol${_fmtCurrency(_purchasingPower)}', const Color(0xFFEF4444), tokens),
                                _impactRow('Purchasing Power Lost', '$_currencySymbol${_fmtCurrency(_totalLoss)} (${_lossPercent.toStringAsFixed(1)}%)', const Color(0xFFEF4444), tokens),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _lossPercent / 100,
                                    backgroundColor: tokens.background,
                                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFEF4444)),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _lossPercent > 50
                                      ? 'Over half your purchasing power has been eroded!'
                                      : _lossPercent > 25
                                          ? 'A significant portion of value has been lost to inflation.'
                                          : _lossPercent > 10
                                              ? 'Inflation is taking a noticeable toll on your money.'
                                              : 'Low impact — but inflation compounds over time.',
                                  style: TextStyle(fontSize: 10, color: tokens.textMuted, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Chart + Breakdown
                  Expanded(
                    child: Column(
                      children: [
                        // Chart
                        Expanded(
                          flex: 3,
                          child: PremiumCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Value Erosion Over Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                const SizedBox(height: 4),
                                Text('The gap between original value and inflation-adjusted purchasing power widens each year',
                                    style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _buildChart(tokens, data),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Year-by-year table
                        Expanded(
                          flex: 2,
                          child: PremiumCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Year-by-Year Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: data.length,
                                    itemBuilder: (context, index) {
                                      final d = data[index];
                                      final isLast = index == data.length - 1;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isLast ? const Color(0xFFEF4444).withValues(alpha: 0.06) : (index % 2 == 0 ? tokens.background : Colors.transparent),
                                          borderRadius: BorderRadius.circular(4),
                                          border: isLast ? Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.12)) : null,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 36,
                                              child: Text('Yr ${d.year}', style: TextStyle(fontSize: 11, fontWeight: isLast ? FontWeight.w700 : FontWeight.w500, color: isLast ? const Color(0xFFEF4444) : tokens.textSecondary)),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(2),
                                                    child: LinearProgressIndicator(
                                                      value: _amount > 0 ? d.futureValue / _amount : 0,
                                                      backgroundColor: tokens.background,
                                                      valueColor: AlwaysStoppedAnimation<Color>(isLast ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                                                      minHeight: 4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 90,
                                              child: Text('$_currencySymbol${_fmtCurrency(d.futureValue)}', style: TextStyle(fontSize: 11, fontWeight: isLast ? FontWeight.w700 : FontWeight.w400, color: isLast ? const Color(0xFFEF4444) : tokens.textPrimary), textAlign: TextAlign.right),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 70,
                                              child: Text('-$_currencySymbol${_fmtCurrency(d.loss)}', style: TextStyle(fontSize: 10, color: isLast ? const Color(0xFFEF4444) : tokens.textMuted), textAlign: TextAlign.right),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildChart(ThemeTokens tokens, List<_YearData> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxVal = _amount * 1.05;
    final spots = data.map((d) => FlSpot(d.year.toDouble(), d.futureValue)).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (v) => FlLine(color: tokens.borderSubtle, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (v, _) => Text('$_currencySymbol${_fmtCurrency(v)}', style: TextStyle(fontSize: 9, color: tokens.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (data.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, _) => Text('Yr ${v.toInt()}', style: TextStyle(fontSize: 9, color: tokens.textMuted)),
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFFEF4444),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: spot.y == data.last.futureValue ? 4 : 2,
                color: spot.y == data.last.futureValue ? const Color(0xFFEF4444) : tokens.accent,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFEF4444).withValues(alpha: 0.15),
                  const Color(0xFFEF4444).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Reference line at original value
          LineChartBarData(
            spots: [FlSpot(0, _amount), FlSpot(data.last.year.toDouble(), _amount)],
            isCurved: false,
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            barWidth: 1.5,
            dashArray: [6, 4],
            dotData: FlDotData(show: false),
          ),
        ],
        minX: 0,
        maxX: data.last.year.toDouble(),
        minY: 0,
        maxY: maxVal,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  Widget _sliderInput({
    required ThemeTokens tokens,
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    String? prefix,
    String? suffix,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
            Text(format(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: tokens.accent,
            inactiveTrackColor: tokens.background,
            thumbColor: tokens.accent,
            overlayColor: tokens.accent.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / step).round().clamp(1, 1000),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _indicator(String label, double rate, ThemeTokens tokens) {
    return Column(
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: rate <= 2 ? const Color(0xFF10B981) : rate <= 6 ? const Color(0xFFF59E0B) : rate <= 15 ? const Color(0xFFEF4444) : const Color(0xFF991B1B),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 2),
        Text('$label ${rate}%', style: TextStyle(fontSize: 8, color: tokens.textMuted)),
      ],
    );
  }

  Widget _impactRow(String label, String value, Color color, ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
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

  String _fmtCurrency(double n) {
    if (_currency == 'INR') {
      if (n.abs() >= 10000000) return '${(n / 10000000).toStringAsFixed(2)}Cr';
      if (n.abs() >= 100000) return '${(n / 100000).toStringAsFixed(2)}L';
      if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
      return n.toStringAsFixed(2);
    } else {
      if (n.abs() >= 1000000000) return '${(n / 1000000000).toStringAsFixed(2)}B';
      if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
      if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
      return n.toStringAsFixed(2);
    }
  }
}

class _YearData {
  final int year;
  final double futureValue;
  final double loss;
  _YearData({required this.year, required this.futureValue, required this.loss});
}
