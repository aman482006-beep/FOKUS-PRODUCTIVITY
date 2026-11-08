import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/empty_state.dart';

// ──────────────────────────────────────────────
// Data Models
// ──────────────────────────────────────────────

class NetWorthEntry {
  final String id;
  String label;
  double amount;
  bool isAsset;
  String note;
  DateTime date;

  NetWorthEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.isAsset,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'amount': amount,
    'isAsset': isAsset,
    'note': note,
    'date': date.toIso8601String(),
  };

  factory NetWorthEntry.fromJson(Map<String, dynamic> json) => NetWorthEntry(
    id: json['id'] as String,
    label: json['label'] as String,
    amount: (json['amount'] as num).toDouble(),
    isAsset: json['isAsset'] as bool,
    note: json['note'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
  );
}

class NetWorthSnapshot {
  final DateTime date;
  final double netWorth;
  final String? note;

  NetWorthSnapshot({required this.date, required this.netWorth, this.note});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'netWorth': netWorth,
    'note': note,
  };

  factory NetWorthSnapshot.fromJson(Map<String, dynamic> json) => NetWorthSnapshot(
    date: DateTime.parse(json['date'] as String),
    netWorth: (json['netWorth'] as num).toDouble(),
    note: json['note'] as String?,
  );
}

// ──────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────

class NetWorthTimelinePage extends StatefulWidget {
  final VoidCallback onBack;
  const NetWorthTimelinePage({super.key, required this.onBack});

  @override
  State<NetWorthTimelinePage> createState() => _NetWorthTimelinePageState();
}

class _NetWorthTimelinePageState extends State<NetWorthTimelinePage> {
  List<NetWorthEntry> _entries = [];
  List<NetWorthSnapshot> _snapshots = [];
  int _idCounter = 0;
  String _currency = 'INR';

  String get _currencySymbol => _currency == 'INR' ? '\u20B9' : r'$';

  bool _showAddForm = false;
  final _labelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _isAsset = true;
  final _noteCtrl = TextEditingController();

  final _snapNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrency();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _snapNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('networth_currency');
    if (saved != null) setState(() => _currency = saved);
  }

  Future<void> _saveCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('networth_currency', _currency);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesData = prefs.getString('net_worth_entries');
    final snapData = prefs.getString('net_worth_snapshots');
    if (entriesData != null) {
      _entries = (jsonDecode(entriesData) as List).map((e) => NetWorthEntry.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (snapData != null) {
      _snapshots = (jsonDecode(snapData) as List).map((e) => NetWorthSnapshot.fromJson(e as Map<String, dynamic>)).toList();
    }
    setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('net_worth_entries', jsonEncode(_entries.map((e) => e.toJson()).toList()));
    await prefs.setString('net_worth_snapshots', jsonEncode(_snapshots.map((e) => e.toJson()).toList()));
  }

  double get _totalAssets => _entries.where((e) => e.isAsset).fold(0.0, (s, e) => s + e.amount);
  double get _totalLiabilities => _entries.where((e) => !e.isAsset).fold(0.0, (s, e) => s + e.amount);
  double get _netWorth => _totalAssets - _totalLiabilities;

  void _addEntry() {
    final label = _labelCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (label.isEmpty || amount <= 0) return;
    setState(() {
      _entries.add(NetWorthEntry(
        id: 'nw_${++_idCounter}',
        label: label,
        amount: amount,
        isAsset: _isAsset,
        note: _noteCtrl.text.trim(),
      ));
      _showAddForm = false;
      _labelCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
    });
    _saveData();
  }

  void _deleteEntry(String id) {
    setState(() => _entries.removeWhere((e) => e.id == id));
    _saveData();
  }

  void _takeSnapshot() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Monthly Snapshot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Worth: ${_currencySymbol}${_fmtCurrency(_netWorth)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _snapNoteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional milestone)', isDense: true),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _snapshots.add(NetWorthSnapshot(
                  date: DateTime.now(),
                  netWorth: _netWorth,
                  note: _snapNoteCtrl.text.trim().isEmpty ? null : _snapNoteCtrl.text.trim(),
                ));
                _snapshots.sort((a, b) => a.date.compareTo(b.date));
              });
              _snapNoteCtrl.clear();
              Navigator.pop(ctx);
              _saveData();
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _deleteSnapshot(int index) {
    setState(() => _snapshots.removeAt(index));
    _saveData();
  }

  void _clearAllSnapshots() {
    if (_snapshots.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Timeline?'),
        content: const Text('This will remove all snapshots but keep your entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); setState(() => _snapshots.clear()); _saveData(); },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final hasData = _entries.isNotEmpty || _snapshots.isNotEmpty;

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: tokens.textPrimary),
                  onPressed: widget.onBack,
                  splashRadius: 20,
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Net Worth Timeline',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: tokens.textPrimary, letterSpacing: -0.5),
                          ),
                          const SizedBox(width: 8),
                          if (_snapshots.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_snapshots.length} snapshots',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tokens.accent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Track your assets, liabilities, and net worth over time',
                        style: TextStyle(fontSize: 13, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Currency toggle
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
                      _currencyTab('INR', '\u20B9', tokens),
                      const SizedBox(width: 2),
                      _currencyTab('USD', r'$', tokens),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Summary Cards ──
            Row(
              children: [
                _summaryCard('Total Assets', '${_currencySymbol}${_fmtCurrency(_totalAssets)}', const Color(0xFF10B981), tokens),
                const SizedBox(width: 10),
                _summaryCard('Total Liabilities', '${_currencySymbol}${_fmtCurrency(_totalLiabilities)}', const Color(0xFFEF4444), tokens),
                const SizedBox(width: 10),
                _summaryCard('Net Worth', '${_currencySymbol}${_fmtCurrency(_netWorth)}', _netWorth >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFEF4444), tokens),
                const SizedBox(width: 10),
                if (_snapshots.length >= 2) ...[
                  _summaryCard(
                    'Change',
                    '${_netWorth >= _snapshots.first.netWorth ? '+' : ''}${_currencySymbol}${_fmtCurrency(_netWorth - _snapshots.first.netWorth)}',
                    _netWorth >= _snapshots.first.netWorth ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    tokens,
                  ),
                  const SizedBox(width: 10),
                ],
                GestureDetector(
                  onTap: _takeSnapshot,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(gradient: tokens.accentGradient, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Snapshot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Main Content ──
            Expanded(
              child: !hasData
                  ? EmptyState(
                      icon: Icons.timeline_outlined,
                      title: 'Start your net worth journey',
                      subtitle: 'Add your first asset or liability to begin tracking',
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Growth chart + Timeline (left)
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PremiumCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Net Worth Growth', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                          if (_snapshots.isNotEmpty)
                                            GestureDetector(
                                              onTap: _clearAllSnapshots,
                                              child: Icon(Icons.delete_sweep_outlined, size: 14, color: tokens.textMuted),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _snapshots.isEmpty
                                            ? 'Record snapshots over time to see your progress'
                                            : '${_snapshots.length} data point${_snapshots.length == 1 ? '' : 's'} \u2014 ${_snapshots.first.date.month}/${_snapshots.first.date.year} to ${_snapshots.last.date.month}/${_snapshots.last.date.year}',
                                        style: TextStyle(fontSize: 10, color: tokens.textMuted),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: _snapshots.length < 2
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.trending_up_rounded, size: 32, color: tokens.textMuted),
                                                    const SizedBox(height: 8),
                                                    Text('Record at least 2 snapshots\nto see your growth chart', style: TextStyle(fontSize: 11, color: tokens.textMuted), textAlign: TextAlign.center),
                                                  ],
                                                ),
                                              )
                                            : _buildChart(tokens),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 1,
                                child: PremiumCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Snapshot Timeline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: _snapshots.isEmpty
                                            ? Center(child: Text('No snapshots yet', style: TextStyle(fontSize: 11, color: tokens.textMuted)))
                                            : ListView.builder(
                                                physics: const BouncingScrollPhysics(),
                                                itemCount: _snapshots.length,
                                                itemBuilder: (context, index) {
                                                  final snap = _snapshots[index];
                                                  final isLast = index == _snapshots.length - 1;
                                                  final prevNW = index > 0 ? _snapshots[index - 1].netWorth : snap.netWorth;
                                                  final change = snap.netWorth - prevNW;
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 8, height: 8,
                                                          decoration: BoxDecoration(
                                                            color: isLast ? tokens.accent : tokens.textMuted,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        if (!isLast) Container(width: 16, height: 1, color: tokens.borderSubtle),
                                                        const SizedBox(width: 8),
                                                        SizedBox(
                                                          width: 70,
                                                          child: Text(
                                                            '${snap.date.month}/${snap.date.year}',
                                                            style: TextStyle(fontSize: 10, fontWeight: isLast ? FontWeight.w600 : FontWeight.w400, color: isLast ? tokens.textPrimary : tokens.textMuted),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '${_currencySymbol}${_fmtCurrency(snap.netWorth)}',
                                                            style: TextStyle(fontSize: 10, fontWeight: isLast ? FontWeight.w700 : FontWeight.w500, color: isLast ? tokens.textPrimary : tokens.textSecondary),
                                                          ),
                                                        ),
                                                        if (index > 0)
                                                          Text(
                                                            '${change >= 0 ? '+' : ''}${_currencySymbol}${_fmtCurrency(change)}',
                                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: change >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                                          ),
                                                        if (snap.note != null && snap.note!.isNotEmpty) ...[
                                                          const SizedBox(width: 6),
                                                          Icon(Icons.star_rounded, size: 12, color: const Color(0xFFF59E0B)),
                                                        ],
                                                        const SizedBox(width: 4),
                                                        GestureDetector(
                                                          onTap: () => _deleteSnapshot(index),
                                                          child: Icon(Icons.close_rounded, size: 10, color: tokens.textMuted),
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
                        const SizedBox(width: 20),

                        // Entries panel (right)
                        SizedBox(
                          width: 280,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _showAddForm = !_showAddForm),
                                      child: Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: tokens.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: tokens.borderSubtle),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(_showAddForm ? Icons.close_rounded : Icons.add_rounded, size: 14, color: tokens.accent),
                                            const SizedBox(width: 4),
                                            Text(_showAddForm ? 'Close Form' : 'Add Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.accent)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (_showAddForm) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: tokens.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.borderSubtle),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          _toggleChip('Asset', true, tokens),
                                          const SizedBox(width: 4),
                                          _toggleChip('Liability', false, tokens),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(child: _formField(_labelCtrl, _isAsset ? 'Asset name' : 'Debt name', tokens)),
                                          const SizedBox(width: 8),
                                          Expanded(child: _formField(_amountCtrl, 'Amount', tokens, isNum: true)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _formField(_noteCtrl, 'Note (optional)', tokens),
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: _addEntry,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(gradient: tokens.accentGradient, borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            _isAsset ? 'Add Asset' : 'Add Liability',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              const SizedBox(height: 8),

                              Expanded(
                                child: _entries.isEmpty
                                    ? EmptyState(
                                        icon: Icons.account_balance_wallet_outlined,
                                        title: 'No entries',
                                        subtitle: 'Add assets or liabilities',
                                      )
                                    : ListView.separated(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: _entries.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                                        itemBuilder: (context, index) {
                                          final e = _entries[index];
                                          return PremiumCard(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 3, height: 28,
                                                  decoration: BoxDecoration(
                                                    color: e.isAsset ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(e.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                                      if (e.note.isNotEmpty)
                                                        Text(e.note, style: TextStyle(fontSize: 9, color: tokens.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${_currencySymbol}${_fmtCurrency(e.amount)}',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e.isAsset ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                                    ),
                                                    Text(e.isAsset ? 'Asset' : 'Liability', style: TextStyle(fontSize: 9, color: tokens.textMuted)),
                                                  ],
                                                ),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () => _deleteEntry(e.id),
                                                  child: Icon(Icons.close_rounded, size: 14, color: tokens.textMuted),
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
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart ──

  Widget _buildChart(ThemeTokens tokens) {
    final spots = _snapshots.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.netWorth);
    }).toList();

    final allValues = _snapshots.map((s) => s.netWorth).toList();
    final minVal = allValues.reduce((a, b) => a < b ? a : b);
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxVal - minVal) * 0.1;
    final chartMin = (minVal - padding).clamp(0, double.infinity).toDouble();
    final chartMax = (maxVal + padding).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (chartMax - chartMin) / 4,
          getDrawingHorizontalLine: (v) => FlLine(color: tokens.borderSubtle, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (v, _) => Text(
                '${_currencySymbol}${_fmtCurrency(v)}',
                style: TextStyle(fontSize: 9, color: tokens.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx >= 0 && idx < _snapshots.length) {
                  final snap = _snapshots[idx];
                  return Text('${snap.date.month}/${snap.date.year}', style: TextStyle(fontSize: 8, color: tokens.textMuted));
                }
                return const Text('');
              },
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
            curveSmoothness: 0.35,
            color: tokens.accent,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: index == spots.length - 1 ? 4 : 2,
                color: index == spots.length - 1 ? tokens.accent : tokens.textMuted.withValues(alpha: 0.5),
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.accent.withValues(alpha: 0.15),
                  tokens.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: chartMin,
        maxY: chartMax,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  // ── Widget helpers ──

  Widget _toggleChip(String label, bool value, ThemeTokens tokens) {
    final isActive = _isAsset == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isAsset = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? (value ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.12))
                : tokens.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? (value ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                  : tokens.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? (value ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                  : tokens.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, ThemeTokens tokens) {
    return Expanded(
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tokens.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint, ThemeTokens tokens, {bool isNum = false}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: TextStyle(fontSize: 12, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 11, color: tokens.textMuted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
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
