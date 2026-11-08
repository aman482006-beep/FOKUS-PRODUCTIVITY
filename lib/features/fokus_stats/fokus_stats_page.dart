import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/premium_button.dart';
import '../../core/providers.dart';
import '../../models/fokus_session.dart';
import '../../models/task.dart';
import '../../services/fokus_history_service.dart';

class FokusStatsPage extends ConsumerStatefulWidget {
  const FokusStatsPage({super.key});

  @override
  ConsumerState<FokusStatsPage> createState() => _FokusStatsPageState();
}

class _FokusStatsPageState extends ConsumerState<FokusStatsPage> {
  String _trendRange = '7D'; // '7D' | '30D' | '90D'
  late Timer _rolloverTimer;
  late String _lastBuildDate;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _lastBuildDate = DateTime.now().toIso8601String().substring(0, 10);
    _rolloverTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (todayStr != _lastBuildDate) {
        _lastBuildDate = todayStr;
        if (mounted) {
          setState(() {});
          ref.invalidate(analyticsProvider);
        }
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _rolloverTimer.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exportData(List<FokusSession> sessions) async {
    try {
      final tasks = ref.read(tasksProvider);
      final analytics = ref.read(analyticsProvider);
      final nonBreakSessions = sessions.where((s) => !s.isBreak && s.durationMinutes > 0).toList();
      final interruptedCount = nonBreakSessions.where((s) => s.isInterrupted).length;
      final completedCount = nonBreakSessions.length - interruptedCount;
      final totalMinutes = nonBreakSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final avgMinutes = nonBreakSessions.isEmpty ? 0.0 : totalMinutes / nonBreakSessions.length;

      final buffer = StringBuffer();

      // ── Section 1: Summary Report ──
      buffer.writeln('═══════════════════════════════════════════════');
      buffer.writeln('  FOKUS — Productivity Performance Report');
      buffer.writeln('═══════════════════════════════════════════════');
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln();

      buffer.writeln('─── SUMMARY ───');
      buffer.writeln('Total Focus Time,${totalMinutes} minutes,${(totalMinutes / 60).toStringAsFixed(1)} hours');
      buffer.writeln('Total Sessions,${nonBreakSessions.length}');
      buffer.writeln('Completed Sessions,${completedCount}');
      buffer.writeln('Interrupted Sessions,${interruptedCount}');
      buffer.writeln('Completion Rate,${nonBreakSessions.isEmpty ? 0 : ((completedCount / nonBreakSessions.length) * 100).toStringAsFixed(1)}%');
      buffer.writeln('Average Session Length,${avgMinutes.toStringAsFixed(1)} minutes');
      buffer.writeln('Current Fokus Streak,${analytics.currentFocusStreak} days');
      buffer.writeln('All-Time Best Streak,${FokusHistoryService.bestStreak()} days');
      buffer.writeln('Today Fokus,${analytics.todayFocusMinutes} minutes');
      buffer.writeln('This Week Fokus,${analytics.weeklyFocusMinutes} minutes');
      buffer.writeln('This Month Fokus,${analytics.monthlyFocusTotalMinutes} minutes');
      buffer.writeln('Total Tasks,${tasks.length}');
      buffer.writeln('Pending Tasks,${tasks.where((t) => !t.done && !t.archived).length}');
      buffer.writeln('Completed Tasks,${tasks.where((t) => t.done).length}');
      buffer.writeln();

      // ── Section 2: Daily Focus Breakdown ──
      buffer.writeln('─── DAILY FOKUS BREAKDOWN ───');
      buffer.writeln('Date,Sessions,Total Minutes,Completed,Interrupted');
      final Map<String, List<FokusSession>> byDate = {};
      for (final s in nonBreakSessions) {
        byDate.putIfAbsent(s.date, () => []).add(s);
      }
      final sortedDates = byDate.keys.toList()..sort();
      for (final date in sortedDates) {
        final daySessions = byDate[date]!;
        final dayTotal = daySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
        final dayCompleted = daySessions.where((s) => !s.isInterrupted).length;
        final dayInterrupted = daySessions.where((s) => s.isInterrupted).length;
        buffer.writeln('$date,${daySessions.length},$dayTotal,$dayCompleted,$dayInterrupted');
      }
      buffer.writeln();

      // ── Section 3: Session Type Breakdown ──
      buffer.writeln('─── SESSION TYPE BREAKDOWN ───');
      buffer.writeln('Type,Count,Total Minutes,Average Minutes');
      final Map<String, List<FokusSession>> byType = {};
      for (final s in nonBreakSessions) {
        byType.putIfAbsent(s.sessionType, () => []).add(s);
      }
      for (final entry in byType.entries) {
        final typeSessions = entry.value;
        final typeTotal = typeSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
        final typeAvg = typeTotal / typeSessions.length;
        buffer.writeln('${entry.key},${typeSessions.length},$typeTotal,${typeAvg.toStringAsFixed(1)}');
      }
      buffer.writeln();

      // ── Section 4: All Sessions Detail ──
      buffer.writeln('─── ALL SESSIONS (DETAILED) ───');
      buffer.writeln('Date,Timestamp,Duration (min),Session Type,Planned (min),Actual (sec),Task ID,Interrupted,Start Time,End Time');
      final sortedSessions = List<FokusSession>.from(sessions.where((s) => !s.isBreak))
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      for (final s in sortedSessions) {
        buffer.writeln(
          '${s.date},'
          '${s.timestamp},'
          '${s.durationMinutes},'
          '${s.sessionType},'
          '${s.plannedDurationMinutes ?? ""},'
          '${s.actualDurationSeconds ?? ""},'
          '${s.taskId ?? ""},'
          '${s.isInterrupted},'
          '${s.startTime ?? ""},'
          '${s.endTime ?? ""}',
        );
      }
      buffer.writeln();

      // ── Section 5: Task Focus Summary ──
      final tasksWithFocus = tasks.where((t) => t.totalFocusMinutes > 0).toList()
        ..sort((a, b) => b.totalFocusMinutes.compareTo(a.totalFocusMinutes));
      if (tasksWithFocus.isNotEmpty) {
        buffer.writeln('─── TASK FOKUS SUMMARY ───');
        buffer.writeln('Task,Total Fokus (min),Sessions Completed,Sessions Interrupted,Completion Rate');
        for (final t in tasksWithFocus) {
          final rate = t.completionRate * 100;
          buffer.writeln(
            '"${t.title.replaceAll('"', '""')}",'
            '${t.totalFocusMinutes},'
            '${t.completedSessions},'
            '${t.interruptedSessions},'
            '${rate.toStringAsFixed(0)}%',
          );
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/fokus_productivity_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10121A),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Report exported! Saved to: $path',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  String _formatDateTime(String timestampStr) {
    try {
      final dt = DateTime.parse(timestampStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final day = dt.day;
      
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      
      return '$month $day, $hour:$minute $period';
    } catch (_) {
      return timestampStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final sessions = ref.watch(fokusHistoryProvider);
    final analytics = ref.watch(analyticsProvider);
    final tasks = ref.watch(tasksProvider);

     // Filter trend data based on selection
    final trendMins = _trendRange == '7D'
        ? analytics.dailyFocusTrend7D
        : _trendRange == '30D'
            ? analytics.dailyFocusTrend30D
            : analytics.dailyFocusTrend90D;
    final trendDates = _trendRange == '7D'
        ? analytics.dailyFocusTrendDates7D
        : _trendRange == '30D'
            ? analytics.dailyFocusTrendDates30D
            : analytics.dailyFocusTrendDates90D;

    final sortedSessions = List<FokusSession>.from(sessions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fokus Analytics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your daily fokus consistency and timer usage metrics',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
                PremiumButton(
                  onTap: () => _exportData(sessions),
                  variant: PremiumButtonVariant.gradient,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'Export CSV Report',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Content Area
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 800) {
                              final cardWidth = (constraints.maxWidth - 12) / 2;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildSummaryCard(
                                      title: "Today's Fokus",
                                      value: '${analytics.todayFocusMinutes.toInt() ~/ 60}h ${analytics.todayFocusMinutes.toInt() % 60}m',
                                      icon: Icons.timer_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildSummaryCard(
                                      title: 'Weekly Fokus',
                                      value: '${analytics.weeklyFocusMinutes.toInt() ~/ 60}h ${analytics.weeklyFocusMinutes.toInt() % 60}m',
                                      icon: Icons.assessment_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildSummaryCard(
                                      title: 'Monthly Total',
                                      value: '${analytics.monthlyFocusTotalMinutes ~/ 60}h ${analytics.monthlyFocusTotalMinutes % 60}m',
                                      icon: Icons.calendar_month_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildSummaryCard(
                                      title: 'Fokus Streak',
                                      value: '${analytics.currentFocusStreak} Day${analytics.currentFocusStreak == 1 ? "" : "s"}',
                                      icon: Icons.local_fire_department_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: _buildSummaryCard(
                                      title: 'Avg Session',
                                      value: '${analytics.averageSessionDuration.round()} Mins',
                                      icon: Icons.circle_notifications_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: "Today's Fokus",
                                      value: '${analytics.todayFocusMinutes.toInt() ~/ 60}h ${analytics.todayFocusMinutes.toInt() % 60}m',
                                      icon: Icons.timer_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: 'Weekly Fokus',
                                      value: '${analytics.weeklyFocusMinutes.toInt() ~/ 60}h ${analytics.weeklyFocusMinutes.toInt() % 60}m',
                                      icon: Icons.assessment_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: 'Monthly Total',
                                      value: '${analytics.monthlyFocusTotalMinutes ~/ 60}h ${analytics.monthlyFocusTotalMinutes % 60}m',
                                      icon: Icons.calendar_month_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: 'Fokus Streak',
                                      value: '${analytics.currentFocusStreak} Day${analytics.currentFocusStreak == 1 ? "" : "s"}',
                                      icon: Icons.local_fire_department_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: 'Avg Session',
                                      value: '${analytics.averageSessionDuration.round()} Mins',
                                      icon: Icons.circle_notifications_outlined,
                                      tokens: tokens,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                    const SizedBox(height: 20),

                    // Main Trend Chart Card
                    PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: PremiumSectionHeader(
                                  icon: Icons.show_chart_rounded,
                                  title: 'Fokus Hours Logged',
                                  subtitle: 'Track your productivity hours over time',
                                ),
                              ),
                              _buildRangeSelectors(
                                selected: _trendRange,
                                onSelect: (v) => setState(() => _trendRange = v),
                                tokens: tokens,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 240,
                            child: _DailyLineChart(
                              data: trendMins,
                              dates: trendDates,
                              tokens: tokens,
                              yAxisMins: false, // Show in hours
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Visual Insights: Heatmap & Weekday Distribution
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 800;
                        final weeklyDistributionCard = PremiumCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PremiumSectionHeader(
                                icon: Icons.bar_chart_rounded,
                                title: 'Weekly Fokus Distribution',
                                subtitle: 'Average daily time spent in fokus sessions',
                              ),
                              const SizedBox(height: 32),
                              _buildWeekdayDistributionChart(
                                analytics.weekdayFocusDistribution,
                                tokens,
                              ),
                            ],
                          ),
                        );

                        final consistencyGridCard = PremiumCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PremiumSectionHeader(
                                icon: Icons.grid_on_rounded,
                                title: 'Fokus Consistency Grid',
                                subtitle: 'Daily fokus session contributions',
                              ),
                              const SizedBox(height: 32),
                              _buildMiniHeatmapGrid(
                                analytics.focusHeatmapData,
                                tokens,
                              ),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              weeklyDistributionCard,
                              const SizedBox(height: 16),
                              consistencyGridCard,
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: weeklyDistributionCard),
                              const SizedBox(width: 16),
                              Expanded(child: consistencyGridCard),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),


                    // Daily Session Log & Productivity Insights
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 800;
                        final dailyTimelineCard = _buildDailyTimelineCard(tokens, sessions, tasks);
                        final productivityInsightsCard = _buildProductivityInsightsCard(tokens, sessions);

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              dailyTimelineCard,
                              const SizedBox(height: 16),
                              productivityInsightsCard,
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: dailyTimelineCard),
                              const SizedBox(width: 16),
                              Expanded(child: productivityInsightsCard),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Recent Sessions Logs
                    PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PremiumSectionHeader(
                            icon: Icons.history_rounded,
                            title: 'Recent Fokus Sessions',
                            subtitle: 'Detailed logs of your completed and interrupted sessions',
                            trailing: Text(
                              '${sortedSessions.length} sessions total',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (sortedSessions.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.timer_off_outlined,
                                      size: 40,
                                      color: tokens.textMuted.safeWithOpacity(0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No fokus sessions recorded yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sortedSessions.take(8).length,
                              separatorBuilder: (context, index) => Divider(
                                color: tokens.borderSubtle,
                                height: 24,
                              ),
                              itemBuilder: (context, index) {
                                final session = sortedSessions[index];
                                final isInterrupted = session.isInterrupted;
                                return Row(
                                  children: [
                                    // Session Type Icon
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isInterrupted
                                            ? tokens.accentSecondary.safeWithOpacity(0.08)
                                            : tokens.accent.safeWithOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isInterrupted
                                            ? Icons.pause_circle_outline_rounded
                                            : Icons.play_circle_outline_rounded,
                                        size: 18,
                                        color: isInterrupted
                                            ? tokens.accentSecondary
                                            : tokens.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Session details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.sessionType,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: tokens.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _formatDateTime(session.timestamp),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: tokens.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Duration
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${session.durationMinutes} mins',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isInterrupted
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isInterrupted
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFDCFCE7),
                                            ),
                                          ),
                                          child: Text(
                                            isInterrupted ? 'Interrupted' : 'Completed',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isInterrupted
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF22C55E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );                                },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Scroll-to-top FAB ──
              Positioned(
                  right: 16,
                  bottom: 16,
                  child: AnimatedScale(
                    scale: _showScrollToTop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _scrollToTop,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: tokens.accentGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.accent.safeWithOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
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



  // Range selector chips
  Widget _buildRangeSelectors({
    required String selected,
    required ValueChanged<String> onSelect,
    required ThemeTokens tokens,
  }) {
    return Row(
      children: ['7D', '30D', '90D'].map((range) {
        final active = selected == range;
        return GestureDetector(
          onTap: () => onSelect(range),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? tokens.accent.safeWithOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active ? tokens.accent.safeWithOpacity(0.3) : tokens.borderSubtle,
              ),
            ),
            child: Text(
              range,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? tokens.accent : tokens.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Summary Metrics Card
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required ThemeTokens tokens,
  }) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: tokens.accent.safeWithOpacity(0.6),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Weekday distribution bar chart (hours per day)
  Widget _buildWeekdayDistributionChart(List<int> weekdayMins, ThemeTokens tokens) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final double maxVal = weekdayMins
        .reduce((a, b) => a > b ? a : b)
        .clamp(60, 99999)
        .toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (i) {
        final mins = i < weekdayMins.length ? weekdayMins[i] : 0;
        final ratio = mins / maxVal;
        return Column(
          children: [
            Text(
              '${(mins / 60.0).toStringAsFixed(1)}h',
              style: TextStyle(
                fontSize: 10,
                color: tokens.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 16,
              height: 120,
              decoration: BoxDecoration(
                color: tokens.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 120 * ratio,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tokens.accentSecondary, tokens.accent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              weekdays[i],
              style: TextStyle(
                fontSize: 10,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }

  // GitHub contribution-style Heatmap grid
  Widget _buildMiniHeatmapGrid(Map<String, int> focusData, ThemeTokens tokens) {
    final now = DateTime.now();
    final startOfWeek = now.add(Duration(days: 7 - now.weekday)); // Sunday of current week

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(12, (w) {
            return Expanded(
              child: Center(
                child: Text(
                  'W${12 - w}',
                  style: TextStyle(
                    fontSize: 8,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ['M', 'W', 'F', 'S'].map((day) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    day,
                    style: TextStyle(fontSize: 8, color: tokens.textMuted),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 12,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 84,
                itemBuilder: (context, index) {
                  final row = index ~/ 12; // 0-6
                  final col = index % 12; // 0-11
                  final daysAgo = ((11 - col) * 7) + (7 - (row + 1));
                  final date = startOfWeek.subtract(Duration(days: daysAgo));
                  final dateStr = date.toIso8601String().substring(0, 10);

                  final mins = focusData[dateStr] ?? 0;
                  final double intensity = mins == 0 ? 0.0 : (mins / 120.0).clamp(0.12, 1.0);
                  final label = '$mins mins fokus';

                  return Tooltip(
                    message: '$dateStr\n$label',
                    child: Container(
                      decoration: BoxDecoration(
                        color: intensity > 0
                            ? tokens.accent.safeWithOpacity(intensity)
                            : tokens.borderSubtle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildDailyTimelineCard(ThemeTokens tokens, List<FokusSession> sessions, List<Task> tasks) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todaySessions = sessions.where((s) => s.date == todayStr).toList();
    todaySessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    String formatTime(String? isoStr) {
      if (isoStr == null) return '';
      try {
        final dt = DateTime.parse(isoStr);
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '$hour:$min';
      } catch (_) {
        return '';
      }
    }

    String getTimeRange(FokusSession s) {
      if (s.startTime != null && s.endTime != null) {
        return '${formatTime(s.startTime)}–${formatTime(s.endTime)}';
      }
      try {
        final dtStart = DateTime.parse(s.timestamp);
        final dtEnd = dtStart.add(Duration(minutes: s.durationMinutes));
        final start = '${dtStart.hour.toString().padLeft(2, '0')}:${dtStart.minute.toString().padLeft(2, '0')}';
        final end = '${dtEnd.hour.toString().padLeft(2, '0')}:${dtEnd.minute.toString().padLeft(2, '0')}';
        return '$start–$end';
      } catch (_) {
        return 'Session';
      }
    }

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.timeline_rounded,
            title: 'Daily Session Log',
            subtitle: 'Chronological timeline of today\'s focus sessions',
          ),
          const SizedBox(height: 20),
          if (todaySessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 32,
                      color: tokens.textMuted.safeWithOpacity(0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No sessions completed today yet',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: todaySessions.take(5).map((s) {
                final task = tasks.where((t) => t.id == s.taskId).firstOrNull;
                final taskName = task?.title ?? 'General Fokus';
                final hex = task?.color ?? '#94A3B8';
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            getTimeRange(s),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.safeWithOpacity(0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: tokens.borderSubtle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  taskName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${s.durationMinutes}m',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: tokens.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                s.isInterrupted
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.check_circle_rounded,
                                size: 13,
                                color: s.isInterrupted
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF22C55E),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProductivityInsightsCard(ThemeTokens tokens, List<FokusSession> sessions) {
    final bestStreak = FokusHistoryService.bestStreak();
    final avgMinutes = FokusHistoryService.averageMinutes().round();

    final Map<int, int> weekdayMinutes = {};
    for (final s in sessions) {
      if (!s.isBreak && s.durationMinutes > 0) {
        try {
          final dt = DateTime.parse(s.timestamp);
          weekdayMinutes[dt.weekday] = (weekdayMinutes[dt.weekday] ?? 0) + s.durationMinutes;
        } catch (_) {}
      }
    }
    String bestDay = 'None yet';
    if (weekdayMinutes.isNotEmpty) {
      final sortedDays = weekdayMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final bestDayNum = sortedDays.first.key;
      const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      bestDay = days[bestDayNum];
    }

    Widget buildInsightRow(IconData icon, Color color, String title, String value, String desc) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.safeWithOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Productivity Insights',
            subtitle: 'AI-assisted analysis of your fokus statistics',
          ),
          const SizedBox(height: 20),
          buildInsightRow(
            Icons.local_fire_department_rounded,
            const Color(0xFFF59E0B),
            'All-Time Best Streak',
            '$bestStreak Day${bestStreak == 1 ? "" : "s"}',
            'Your longest streak of consecutive fokus days.',
          ),
          buildInsightRow(
            Icons.speed_rounded,
            const Color(0xFF3B82F6),
            'Avg Session Length',
            '$avgMinutes mins',
            'Your typical fokus session duration.',
          ),
          buildInsightRow(
            Icons.event_available_rounded,
            const Color(0xFF10B981),
            'Most Productive Day',
            bestDay,
            'The day of the week you log the most fokus time.',
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// DAILY FOCUS LINE CHART
// ──────────────────────────────────────────────
class _DailyLineChart extends StatelessWidget {
  final List<int> data;
  final List<DateTime> dates;
  final ThemeTokens tokens;
  final bool yAxisMins;

  const _DailyLineChart({
    required this.data,
    required this.dates,
    required this.tokens,
    required this.yAxisMins,
  });

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No fokus data available.'));
    }

    final double multiplier = yAxisMins ? 1.0 : (1.0 / 60.0);
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble() * multiplier);
    }).toList();

    final maxVal = (data.reduce((a, b) => a > b ? a : b).toDouble() * multiplier)
        .clamp(1.0, 99999.0);

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
                if (idx < 0 || idx >= dates.length) return const SizedBox();
                final d = dates[idx];
                final showLabel = dates.length <= 7 ||
                    idx % (dates.length ~/ 4).clamp(1, 100) == 0 ||
                    idx == dates.length - 1;
                if (!showLabel) return const SizedBox();
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
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  yAxisMins ? '${value.toInt()}m' : '${value.toStringAsFixed(1)}h',
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
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxVal * 1.15,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                if (idx < 0 || idx >= dates.length) return null;
                final d = dates[idx];
                final minutesVal = data[idx];
                final durationStr = _formatMinutes(minutesVal);
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
              show: data.length <= 7,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: tokens.accent,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  tokens.accent.safeWithOpacity(0.24),
                  tokens.accent.safeWithOpacity(0.0)
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
