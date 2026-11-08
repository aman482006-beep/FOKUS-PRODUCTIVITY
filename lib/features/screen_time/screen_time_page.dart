import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../services/screen_time_service.dart';

/// Screen Time page ("Your Reality") — tracks and displays active application usage.
class ScreenTimePage extends ConsumerStatefulWidget {
  const ScreenTimePage({super.key});

  @override
  ConsumerState<ScreenTimePage> createState() => _ScreenTimePageState();
}

class _ScreenTimePageState extends ConsumerState<ScreenTimePage> {
  final ScrollController _scrollController = ScrollController();
  List<AppUsageEntry> _todayUsage = [];
  List<MapEntry<DateTime, int>> _historyUsage = [];
  int _todayTotalSeconds = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh screen time data every 10 seconds while page is active
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() => _isLoading = true);
      }
      final today = await ScreenTimeService.getTodayUsage();
      final total = await ScreenTimeService.getTodayTotalSeconds();
      final history = await ScreenTimeService.getDailyHistoryLastDays(7);

      if (mounted) {
        setState(() {
          _todayUsage = today;
          _todayTotalSeconds = total;
          _historyUsage = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading screen time data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = FocusOsTheme.of(context);
        return AlertDialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Clear Reality Logs?',
            style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'This will permanently delete all app tracking history. This cannot be undone.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ScreenTimeService.clearAll();
      _loadData();
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'productivity':
        return const Color(0xFF10B981); // Emerald Green
      case 'browser':
        return const Color(0xFF3B82F6); // Blue
      case 'game':
        return const Color(0xFFF59E0B); // Amber
      case 'social':
        return const Color(0xFFEC4899); // Pink
      case 'music':
        return const Color(0xFF8B5CF6); // Purple
      case 'video':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray (Other)
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'productivity':
        return Icons.code_rounded;
      case 'browser':
        return Icons.language_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'social':
        return Icons.chat_bubble_outline_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'video':
        return Icons.play_circle_outline_rounded;
      default:
        return Icons.widgets_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculations
    final prodSeconds = _todayUsage
        .where((e) => e.category.toLowerCase() == 'productivity')
        .fold(0, (sum, e) => sum + e.totalSeconds);
    final distractSeconds = _todayTotalSeconds - prodSeconds;
    final prodRatio = _todayTotalSeconds > 0 ? (prodSeconds / _todayTotalSeconds) : 0.0;
    final distractRatio = _todayTotalSeconds > 0 ? (distractSeconds / _todayTotalSeconds) : 0.0;

    final mostUsedApp = _todayUsage.isNotEmpty ? _todayUsage.first.appName : 'None';
    final mostUsedAppTime = _todayUsage.isNotEmpty ? _formatDuration(_todayUsage.first.totalSeconds) : '0s';

    // Grouping by category
    final categoryTotals = <String, int>{};
    for (final entry in _todayUsage) {
      categoryTotals[entry.category] = (categoryTotals[entry.category] ?? 0) + entry.totalSeconds;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Reality',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The raw, unfiltered truth of where your daily fokus is spent.',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _todayUsage.isEmpty ? null : _clearData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.surfaceAlt,
                    foregroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Reset Tracking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Main scrollable body ──
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
                child: motion.PremiumStaggeredEnter(
                  staggerDelay: const Duration(milliseconds: 60),
                  children: [
                    // 1. KPI Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'TOTAL SCREEN TIME',
                            value: _formatDuration(_todayTotalSeconds),
                            subtitle: 'Tracked active usage today',
                            icon: Icons.hourglass_top_rounded,
                            iconColor: tokens.accent,
                            tokens: tokens,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'MOST USED APPLICATION',
                            value: mostUsedApp,
                            subtitle: 'Active for $mostUsedAppTime',
                            icon: Icons.monitor_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            tokens: tokens,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'PRODUCTIVITY RATIO',
                            value: '${(prodRatio * 100).toStringAsFixed(0)}%',
                            subtitle: '${_formatDuration(prodSeconds)} productive vs ${_formatDuration(distractSeconds)} other',
                            icon: Icons.verified_user_rounded,
                            iconColor: const Color(0xFF10B981),
                            tokens: tokens,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2. Trend & Category Split
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 768;

                        final trendCard = PremiumCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PremiumSectionHeader(
                                icon: Icons.show_chart_rounded,
                                title: 'Usage Trend (Last 7 Days)',
                                subtitle: 'Is your daily screen time increasing or decreasing?',
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16, right: 16),
                                  child: _ScreenTimeHistoryChart(
                                    history: _historyUsage,
                                    tokens: tokens,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        final breakdownCard = PremiumCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PremiumSectionHeader(
                                icon: Icons.pie_chart_outline_rounded,
                                title: 'Category Breakdown',
                                subtitle: 'Ratio of time spent by category',
                              ),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  // Donut ratio indicator
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      height: 10,
                                      width: double.infinity,
                                      color: tokens.borderSubtle,
                                      child: Row(
                                        children: [
                                          if (prodRatio > 0)
                                            Expanded(
                                              flex: (prodRatio * 100).toInt(),
                                              child: Container(color: const Color(0xFF10B981)),
                                            ),
                                          if (distractRatio > 0)
                                            Expanded(
                                              flex: (distractRatio * 100).toInt(),
                                              child: Container(color: const Color(0xFFEF4444)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(width: 8, height: 8, color: const Color(0xFF10B981)),
                                          const SizedBox(width: 4),
                                          Text('Productive (${(prodRatio * 100).toStringAsFixed(0)}%)',
                                              style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Container(width: 8, height: 8, color: const Color(0xFFEF4444)),
                                          const SizedBox(width: 4),
                                          Text('Other/Distracting (${(distractRatio * 100).toStringAsFixed(0)}%)',
                                              style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  ...sortedCategories.map((entry) {
                                    final catName = entry.key;
                                    final catSeconds = entry.value;
                                    final percent = _todayTotalSeconds > 0 ? (catSeconds / _todayTotalSeconds) : 0.0;
                                    final catColor = _getCategoryColor(catName);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(_getCategoryIcon(catName), size: 14, color: catColor),
                                                  const SizedBox(width: 6),
                                                  Text(catName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                                                ],
                                              ),
                                              Text(
                                                '${_formatDuration(catSeconds)} (${(percent * 100).toStringAsFixed(0)}%)',
                                                style: TextStyle(fontSize: 11, color: tokens.textMuted),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: LinearProgressIndicator(
                                              value: percent,
                                              minHeight: 4,
                                              backgroundColor: tokens.borderSubtle,
                                              valueColor: AlwaysStoppedAnimation(catColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 280,
                                child: trendCard,
                              ),
                              const SizedBox(height: 16),
                              breakdownCard,
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: trendCard),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: breakdownCard),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3. Tracked Applications Table
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PremiumSectionHeader(
                            icon: Icons.list_alt_rounded,
                            title: 'Tracked Application Details',
                            subtitle: 'Process name and absolute active time logs',
                          ),
                          const SizedBox(height: 16),
                          _todayUsage.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(40),
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      Icon(Icons.hourglass_empty_rounded, size: 36, color: tokens.textMuted),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No application usage tracked yet',
                                        style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tracking starts automatically in the background when app is running.',
                                        style: TextStyle(color: tokens.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _todayUsage.length,
                                  separatorBuilder: (_, __) => Divider(color: tokens.borderSubtle, height: 1),
                                  itemBuilder: (context, idx) {
                                    final entry = _todayUsage[idx];
                                    final catColor = _getCategoryColor(entry.category);
                                    final pct = _todayTotalSeconds > 0 ? (entry.totalSeconds / _todayTotalSeconds) : 0.0;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        children: [
                                          Icon(_getCategoryIcon(entry.category), size: 18, color: catColor),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.appName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: tokens.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  entry.category.toUpperCase(),
                                                  style: GoogleFonts.shareTechMono(
                                                    fontSize: 9,
                                                    color: catColor,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _formatDuration(entry.totalSeconds),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: tokens.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${(pct * 100).toStringAsFixed(1)}% of total',
                                                  style: TextStyle(fontSize: 10, color: tokens.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required ThemeTokens tokens,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tokens.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: tokens.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenTimeHistoryChart extends StatelessWidget {
  final List<MapEntry<DateTime, int>> history;
  final ThemeTokens tokens;

  const _ScreenTimeHistoryChart({
    required this.history,
    required this.tokens,
  });

  String _localFormatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No history data available.'));
    }

    final spots = history.asMap().entries.map((entry) {
      // Y value is hours
      final hours = entry.value.value / 3600.0;
      return FlSpot(entry.key.toDouble(), hours);
    }).toList();

    double maxHours = history.map((e) => e.value / 3600.0).fold(1.0, (m, val) => val > m ? val : m);
    // Add some padding on top of the chart
    maxHours = (maxHours * 1.25).clamp(1.0, 24.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: tokens.borderSubtle,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= history.length) return const SizedBox();
                final d = history[idx].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}h',
                  style: TextStyle(color: tokens.textMuted, fontSize: 8),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (history.length - 1).toDouble(),
        minY: 0,
        maxY: maxHours,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                if (idx < 0 || idx >= history.length) return null;
                final entry = history[idx];
                final d = entry.key;
                final durationStr = _localFormatDuration(entry.value);
                return LineTooltipItem(
                  '${d.day}/${d.month}\n$durationStr',
                  TextStyle(
                    color: tokens.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: tokens.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: tokens.accent,
                strokeWidth: 1.5,
                strokeColor: tokens.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  tokens.accent.withValues(alpha: 0.25),
                  tokens.accent.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
