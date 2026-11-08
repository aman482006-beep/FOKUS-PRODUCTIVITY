import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/empty_state.dart';

// ──────────────────────────────────────────────
// Data Model
// ──────────────────────────────────────────────

class Subscription {
  final String id;
  String name;
  double cost;
  bool isYearly;
  DateTime renewalDate;
  String category;
  String notes;
  bool isActive;

  Subscription({
    required this.id,
    required this.name,
    required this.cost,
    required this.isYearly,
    required this.renewalDate,
    this.category = '',
    this.notes = '',
    this.isActive = true,
  });

  double get monthlyCost => isYearly ? cost / 12 : cost;
  double get yearlyCost => isYearly ? cost : cost * 12;
  int get daysUntilRenewal => DateTime.now().toUtc().difference(renewalDate.toUtc()).inDays.abs();
  bool get isDueSoon => daysUntilRenewal <= 7;
  bool get isOverdue => renewalDate.isBefore(DateTime.now()) && isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cost': cost,
    'isYearly': isYearly,
    'renewalDate': renewalDate.toIso8601String(),
    'category': category,
    'notes': notes,
    'isActive': isActive,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    name: json['name'] as String,
    cost: (json['cost'] as num).toDouble(),
    isYearly: json['isYearly'] as bool,
    renewalDate: DateTime.parse(json['renewalDate'] as String),
    category: json['category'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );
}

// ──────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────

class SubscriptionTrackerPage extends StatefulWidget {
  final VoidCallback onBack;
  const SubscriptionTrackerPage({super.key, required this.onBack});

  @override
  State<SubscriptionTrackerPage> createState() => _SubscriptionTrackerPageState();
}

class _SubscriptionTrackerPageState extends State<SubscriptionTrackerPage> {
  List<Subscription> _subscriptions = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterCategory = 'all';
  String _currency = 'USD';

  final _nameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  bool _isYearly = false;
  DateTime _renewalDate = DateTime.now().add(const Duration(days: 30));
  String _category = 'Entertainment';
  final _notesCtrl = TextEditingController();
  bool _showAddForm = false;
  int _idCounter = 0;

  static const _categories = [
    'Entertainment', 'Productivity', 'Cloud', 'Music', 'Video',
    'News', 'Finance', 'Health', 'Education', 'Other',
  ];

  String get _currencySymbol => _currency == 'INR' ? '₹' : '\$';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('subscriptions');
    if (data != null) {
      final list = (jsonDecode(data) as List)
          .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _subscriptions = list);
    }
    final currency = prefs.getString('subscriptions_currency');
    if (currency != null) {
      setState(() => _currency = currency);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscriptions', jsonEncode(_subscriptions.map((s) => s.toJson()).toList()));
    await prefs.setString('subscriptions_currency', _currency);
  }

  List<Subscription> get _filtered {
    var list = _subscriptions.where((s) => _filterCategory == 'all' || s.category == _filterCategory).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  double get _monthlyTotal => _subscriptions.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.monthlyCost);
  double get _yearlyTotal => _subscriptions.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.yearlyCost);
  int get _activeCount => _subscriptions.where((s) => s.isActive).length;
  int get _dueSoonCount => _subscriptions.where((s) => s.isActive && s.isDueSoon).length;

  Map<String, double> get _categoryBreakdown {
    final map = <String, double>{};
    for (final s in _subscriptions.where((s) => s.isActive)) {
      map[s.category] = (map[s.category] ?? 0) + s.monthlyCost;
    }
    return map;
  }

  void _addSubscription() {
    final name = _nameCtrl.text.trim();
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    if (name.isEmpty || cost <= 0) return;

    setState(() {
      _subscriptions.add(Subscription(
        id: 'sub_${++_idCounter}',
        name: name,
        cost: cost,
        isYearly: _isYearly,
        renewalDate: _renewalDate,
        category: _category,
        notes: _notesCtrl.text.trim(),
      ));
      _showAddForm = false;
      _nameCtrl.clear();
      _costCtrl.clear();
      _notesCtrl.clear();
      _isYearly = false;
      _renewalDate = DateTime.now().add(const Duration(days: 30));
    });
    _saveData();
  }

  void _deleteSubscription(String id) {
    setState(() => _subscriptions.removeWhere((s) => s.id == id));
    _saveData();
  }

  void _toggleActive(String id) {
    setState(() {
      final idx = _subscriptions.indexWhere((s) => s.id == id);
      if (idx >= 0) _subscriptions[idx].isActive = !_subscriptions[idx].isActive;
    });
    _saveData();
  }

  void _showEditDialog(Subscription sub) {
    final nameCtrl = TextEditingController(text: sub.name);
    final costCtrl = TextEditingController(text: sub.cost.toString());
    var yearly = sub.isYearly;
    var renewDate = sub.renewalDate;
    var category = sub.category;
    final notesCtrl = TextEditingController(text: sub.notes);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Edit Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost', isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Yearly', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: yearly,
                      onChanged: (v) => setDlgState(() => yearly = v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Renewal', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: renewDate, firstDate: DateTime(2020), lastDate: DateTime(2050));
                        if (picked != null) setDlgState(() => renewDate = picked);
                      },
                      child: Text('${renewDate.month}/${renewDate.day}/${renewDate.year}', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) { if (v != null) setDlgState(() => category = v); },
                  isDense: true,
                ),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', isDense: true), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                sub.name = nameCtrl.text.trim();
                sub.cost = double.tryParse(costCtrl.text) ?? sub.cost;
                sub.isYearly = yearly;
                sub.renewalDate = renewDate;
                sub.category = category;
                sub.notes = notesCtrl.text.trim();
                for (final c in [nameCtrl, costCtrl, notesCtrl]) c.dispose();
                Navigator.pop(ctx);
                setState(() {});
                _saveData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final filtered = _filtered;
    final catBreakdown = _categoryBreakdown;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subscription Tracker', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: tokens.textPrimary, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Track recurring expenses and upcoming renewals', style: TextStyle(fontSize: 13, color: tokens.textMuted)),
                    ],
                  ),
                ),
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
                      _currencyTab('USD', '\$', tokens),
                      const SizedBox(width: 2),
                      _currencyTab('INR', '₹', tokens),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                _summaryCard('Monthly Total', '$_currencySymbol${_formatNum(_monthlyTotal)}', const Color(0xFF3B82F6), tokens),
                const SizedBox(width: 10),
                _summaryCard('Yearly Total', '$_currencySymbol${_formatNum(_yearlyTotal)}', const Color(0xFF8B5CF6), tokens),
                const SizedBox(width: 10),
                _summaryCard('Active Subs', '$_activeCount', const Color(0xFF10B981), tokens),
                const SizedBox(width: 10),
                _summaryCard('Due Soon', '$_dueSoonCount', _dueSoonCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), tokens),
              ],
            ),
            const SizedBox(height: 20),

            // Main content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category breakdown panel
                  SizedBox(
                    width: 200,
                    child: PremiumCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: catBreakdown.isEmpty
                                ? Center(child: Text('No active subs', style: TextStyle(fontSize: 11, color: tokens.textMuted)))
                                : ListView(
                                    children: catBreakdown.entries.map((e) {
                                      final pct = _monthlyTotal > 0 ? (e.value / _monthlyTotal * 100) : 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(e.key, style: TextStyle(fontSize: 10, color: tokens.textSecondary), overflow: TextOverflow.ellipsis)),
                                                Text('$_currencySymbol${e.value.toStringAsFixed(1)}/mo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: pct / 100,
                                                backgroundColor: tokens.background,
                                                valueColor: AlwaysStoppedAnimation(_catColor(e.key)),
                                                minHeight: 4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Subscription list
                  Expanded(
                    child: Column(
                      children: [
                        // Search + filters
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: tokens.borderSubtle)),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, size: 16, color: tokens.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(fontSize: 12, color: tokens.textPrimary),
                                      decoration: InputDecoration(hintText: 'Search subscriptions...', hintStyle: TextStyle(fontSize: 12, color: tokens.textMuted), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      onChanged: (v) => setState(() => _searchQuery = v),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Category filter
                            Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: tokens.borderSubtle)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _filterCategory,
                                  style: TextStyle(fontSize: 11, color: tokens.textPrimary),
                                  items: [const DropdownMenuItem(value: 'all', child: Text('All')), ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
                                  onChanged: (v) { if (v != null) setState(() => _filterCategory = v); },
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _iconBtn(Icons.add_rounded, 'Add', () => setState(() => _showAddForm = !_showAddForm), tokens),
                          ],
                        ),

                        // Add form
                        if (_showAddForm) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: tokens.borderSubtle)),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _formField(_nameCtrl, 'Name', tokens)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _formField(_costCtrl, 'Monthly / Yearly Cost', tokens, isNum: true)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Yearly billing?', style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 8),
                                    Switch(value: _isYearly, onChanged: (v) => setState(() => _isYearly = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    const Spacer(),
                                    const Text('Renewal:', style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showDatePicker(context: context, initialDate: _renewalDate, firstDate: DateTime(2020), lastDate: DateTime(2050));
                                        if (picked != null) setState(() => _renewalDate = picked);
                                      },
                                      child: Text('${_renewalDate.month}/${_renewalDate.day}/${_renewalDate.year}', style: TextStyle(fontSize: 11, color: tokens.accent)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child:                                      DropdownButtonFormField<String>(
                                        initialValue: _category,
                                        decoration: const InputDecoration(labelText: 'Category', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: InputBorder.none),
                                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                        onChanged: (v) { if (v != null) setState(() => _category = v); },
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: _formField(_notesCtrl, 'Notes (optional)', tokens)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () { setState(() => _showAddForm = false); _nameCtrl.clear(); _costCtrl.clear(); _notesCtrl.clear(); },
                                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: tokens.background, borderRadius: BorderRadius.circular(8)), child: Text('Cancel', style: TextStyle(fontSize: 11, color: tokens.textMuted))),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _addSubscription,
                                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(gradient: tokens.accentGradient, borderRadius: BorderRadius.circular(8)), child: Text('Add Subscription', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // List
                        Expanded(
                          child: filtered.isEmpty
                              ? EmptyState(icon: Icons.subscriptions_outlined, title: _subscriptions.isEmpty ? 'No subscriptions yet' : 'No matches', subtitle: _subscriptions.isEmpty ? 'Tap + to add your first subscription' : null)
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final s = filtered[index];
                                    return PremiumCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Opacity(
                                        opacity: s.isActive ? 1.0 : 0.5,
                                        child: Row(
                                          children: [
                                            // Active indicator
                                            GestureDetector(
                                              onTap: () => _toggleActive(s.id),
                                              child: Container(
                                                width: 18, height: 18,
                                                decoration: BoxDecoration(
                                                  color: s.isActive ? _catColor(s.category).withValues(alpha: 0.15) : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: s.isActive ? _catColor(s.category) : tokens.textMuted, width: 1.5),
                                                ),
                                                child: s.isActive ? Icon(Icons.check, size: 12, color: _catColor(s.category)) : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(s.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                                      const SizedBox(width: 6),
                                                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: _catColor(s.category).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(s.category, style: TextStyle(fontSize: 9, color: _catColor(s.category), fontWeight: FontWeight.w500))),
                                                    ],
                                                  ),
                                                  if (s.notes.isNotEmpty) ...[const SizedBox(height: 2), Text(s.notes, style: TextStyle(fontSize: 10, color: tokens.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)],
                                                ],
                                              ),
                                            ),
                                            // Cost + Renewal
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('$_currencySymbol${_formatNum(s.isYearly ? s.yearlyCost : s.monthlyCost)}/${s.isYearly ? 'yr' : 'mo'}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: s.isOverdue ? const Color(0xFFEF4444).withValues(alpha: 0.12) : s.isDueSoon ? const Color(0xFFF59E0B).withValues(alpha: 0.12) : tokens.background,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    s.isOverdue ? 'Overdue!' : s.isDueSoon ? '${s.daysUntilRenewal}d left' : '${s.daysUntilRenewal}d',
                                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: s.isOverdue ? const Color(0xFFEF4444) : s.isDueSoon ? const Color(0xFFF59E0B) : tokens.textMuted),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(onTap: () => _showEditDialog(s), child: Icon(Icons.edit_outlined, size: 14, color: tokens.textMuted)),
                                            const SizedBox(width: 6),
                                            GestureDetector(onTap: () => _deleteSubscription(s.id), child: Icon(Icons.close_rounded, size: 14, color: tokens.textMuted)),
                                          ],
                                        ),
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

  Color _catColor(String cat) {
    const map = {
      'Entertainment': Color(0xFFEF4444),
      'Productivity': Color(0xFF3B82F6),
      'Cloud': Color(0xFF6366F1),
      'Music': Color(0xFFEC4899),
      'Video': Color(0xFFF59E0B),
      'News': Color(0xFF8B5CF6),
      'Finance': Color(0xFF10B981),
      'Health': Color(0xFF14B8A6),
      'Education': Color(0xFF06B6D4),
    };
    return map[cat] ?? const Color(0xFF6B7280);
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap, ThemeTokens tokens) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: tokens.borderSubtle)),
        child: Icon(icon, size: 16, color: tokens.textPrimary),
      ),
    );
  }

  Widget _currencyTab(String code, String symbol, ThemeTokens tokens) {
    final active = _currency == code;
    return GestureDetector(
      onTap: () {
        setState(() => _currency = code);
        _saveData();
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

  Widget _formField(TextEditingController ctrl, String hint, ThemeTokens tokens, {bool isNum = false}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: tokens.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: TextStyle(fontSize: 12, color: tokens.textPrimary),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontSize: 11, color: tokens.textMuted), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      ),
    );
  }

  String _formatNum(double n) {
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(2);
  }
}
