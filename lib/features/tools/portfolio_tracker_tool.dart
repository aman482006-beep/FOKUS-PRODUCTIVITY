import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../models/portfolio_asset.dart';


class PortfolioTrackerPage extends StatefulWidget {
  final VoidCallback onBack;
  const PortfolioTrackerPage({super.key, required this.onBack});

  @override
  State<PortfolioTrackerPage> createState() => _PortfolioTrackerPageState();
}

class _PortfolioTrackerPageState extends State<PortfolioTrackerPage> {
  // State variables
  List<PortfolioAsset> _assets = [];

  bool _showAddForm = false;
  String _searchQuery = '';
  String _activeTab = 'Active'; // 'Active' or 'Sold'
  String _chartView = 'Category'; // 'Category', 'Name', or 'Subcategory'
  String? _selectedSubcategory = 'Equity (Stocks)'; // Category for subcategory chart view
  int _touchedChartIndex = -1;

  // Form Controllers
  final _nameCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _currentPriceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedCategory = 'Equity (Stocks)';
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'Equity (Stocks)',
    'Equity Options',
    'Futures & Derivatives',
    'Forex / Currencies',
    'Bonds & Fixed Income',
    'Mutual Funds & ETFs',
    'Cryptocurrency',
    'Real Estate & REITs',
    'Commodities (Gold, Oil, etc.)',
    'Cash & Cash Equivalents',
    'Alternative Assets (Art, Collectibles)',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _buyPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _currentPriceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Data Persistence ──

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final rawAssets = prefs.getString('portfolio_assets_list');
      if (rawAssets != null) {
        try {
          final List decoded = jsonDecode(rawAssets);
          _assets = decoded
              .map((e) => PortfolioAsset.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } catch (_) {}
      }
    });
  }

  Future<void> _saveAssets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'portfolio_assets_list', jsonEncode(_assets.map((e) => e.toJson()).toList()));
  }


  // ── Calculations ──

  double get _totalInvested => _assets
      .where((a) => !a.isSold)
      .fold(0.0, (sum, a) => sum + a.invested);

  double get _totalCurrentValue => _assets
      .where((a) => !a.isSold)
      .fold(0.0, (sum, a) => sum + a.currentValue);

  double get _unrealisedPL => _assets
      .where((a) => !a.isSold)
      .fold(0.0, (sum, a) => sum + a.unrealised);

  double get _realisedPL => _assets
      .where((a) => a.isSold)
      .fold(0.0, (sum, a) => sum + a.realised);

  double get _netPL => _realisedPL + _unrealisedPL;

  // ── Actions ──

  void _addAssetTransaction() {
    final name = _nameCtrl.text.trim();
    final buyPrice = double.tryParse(_buyPriceCtrl.text) ?? 0.0;
    final quantity = double.tryParse(_quantityCtrl.text) ?? 0.0;
    final currentPrice = double.tryParse(_currentPriceCtrl.text) ?? buyPrice;
    final notes = _notesCtrl.text.trim();

    if (name.isEmpty || buyPrice <= 0 || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out Name, Buy Price, and Quantity with positive numbers.')),
      );
      return;
    }

    final newAsset = PortfolioAsset(
      id: 'asset_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: _selectedCategory,
      buyPrice: buyPrice,
      quantity: quantity,
      currentPrice: currentPrice,
      purchaseDate: _selectedDate,
      notes: notes,
    );

    setState(() {
      _assets.add(newAsset);
      _showAddForm = false;
      _clearForm();
    });
    _saveAssets();
  }

  void _clearForm() {
    _nameCtrl.clear();
    _buyPriceCtrl.clear();
    _quantityCtrl.clear();
    _currentPriceCtrl.clear();
    _notesCtrl.clear();
    _selectedCategory = 'Equity (Stocks)';
    _selectedDate = DateTime.now();
  }

  void _deleteAsset(String id) {
    setState(() {
      _assets.removeWhere((a) => a.id == id);
    });
    _saveAssets();
  }

  void _sellAsset(PortfolioAsset asset, double sellPrice, DateTime sellDate) {
    setState(() {
      final idx = _assets.indexWhere((a) => a.id == asset.id);
      if (idx != -1) {
        _assets[idx] = asset.copyWith(
          isSold: true,
          sellPrice: sellPrice,
          sellDate: sellDate,
        );
      }
    });
    _saveAssets();
  }

  void _editAsset(PortfolioAsset asset, {
    required String name,
    required String category,
    required double buyPrice,
    required double quantity,
    required double currentPrice,
    required DateTime purchaseDate,
    required String notes,
    double? sellPrice,
    DateTime? sellDate,
    bool? isSold,
  }) {
    setState(() {
      final idx = _assets.indexWhere((a) => a.id == asset.id);
      if (idx != -1) {
        _assets[idx] = asset.copyWith(
          name: name,
          category: category,
          buyPrice: buyPrice,
          quantity: quantity,
          currentPrice: currentPrice,
          purchaseDate: purchaseDate,
          notes: notes,
          sellPrice: sellPrice,
          sellDate: sellDate,
          isSold: isSold,
        );
      }
    });
    _saveAssets();
  }

  // ── Modals & Dialogs ──

  void _showSellDialog(PortfolioAsset asset, ThemeTokens tokens) {
    final priceCtrl = TextEditingController(text: asset.currentPrice.toString());
    DateTime sellDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: tokens.surface,
          title: Text('Sell Asset: ${asset.name}', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(priceCtrl, 'Sell Price (\$)', tokens, isNum: true),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sell Date:', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: sellDate,
                        firstDate: asset.purchaseDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDlgState(() => sellDate = picked);
                      }
                    },
                    icon: Icon(Icons.calendar_today_rounded, size: 14, color: tokens.accent),
                    label: Text(
                      '${sellDate.day}/${sellDate.month}/${sellDate.year}',
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final sellPrice = double.tryParse(priceCtrl.text) ?? asset.currentPrice;
                _sellAsset(asset, sellPrice, sellDate);
                Navigator.pop(ctx);
              },
              child: const Text('Confirm Sale'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(PortfolioAsset asset, ThemeTokens tokens) {
    final nameCtrl = TextEditingController(text: asset.name);
    final buyCtrl = TextEditingController(text: asset.buyPrice.toString());
    final qtyCtrl = TextEditingController(text: asset.quantity.toString());
    final curCtrl = TextEditingController(text: asset.currentPrice.toString());
    final notesCtrl = TextEditingController(text: asset.notes);
    final sellPriceCtrl = TextEditingController(text: asset.sellPrice?.toString() ?? '');
    
    String category = asset.category;
    DateTime purchaseDate = asset.purchaseDate;
    DateTime? sellDate = asset.sellDate;
    bool isSold = asset.isSold;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: tokens.surface,
          title: Text('Edit Transaction', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogTextField(nameCtrl, 'Asset Name', tokens),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    dropdownColor: tokens.surface,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: tokens.textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _dialogTextField(buyCtrl, 'Buy Price (\$)', tokens, isNum: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _dialogTextField(qtyCtrl, 'Quantity', tokens, isNum: true)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _dialogTextField(curCtrl, 'Current Price (\$)', tokens, isNum: true),
                  const SizedBox(height: 8),
                  _dialogTextField(notesCtrl, 'Notes', tokens, maxLines: 2),
                  const SizedBox(height: 16),
                  
                  // Purchase Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Purchase Date:', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: purchaseDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDlgState(() => purchaseDate = picked);
                          }
                        },
                        icon: Icon(Icons.calendar_today_rounded, size: 14, color: tokens.accent),
                        label: Text(
                          '${purchaseDate.day}/${purchaseDate.month}/${purchaseDate.year}',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Status Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Active'),
                            selected: !isSold,
                            onSelected: (val) {
                              if (val) setDlgState(() => isSold = false);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Sold'),
                            selected: isSold,
                            onSelected: (val) {
                              if (val) setDlgState(() => isSold = true);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  if (isSold) ...[
                    const SizedBox(height: 8),
                    _dialogTextField(sellPriceCtrl, 'Sell Price (\$)', tokens, isNum: true),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sell Date:', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: sellDate ?? DateTime.now(),
                              firstDate: purchaseDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDlgState(() => sellDate = picked);
                            }
                          },
                          icon: Icon(Icons.calendar_today_rounded, size: 14, color: tokens.accent),
                          label: Text(
                            sellDate != null
                                ? '${sellDate!.day}/${sellDate!.month}/${sellDate!.year}'
                                : 'Select Date',
                            style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final buyPrice = double.tryParse(buyCtrl.text) ?? asset.buyPrice;
                final quantity = double.tryParse(qtyCtrl.text) ?? asset.quantity;
                final currentPrice = double.tryParse(curCtrl.text) ?? asset.currentPrice;
                final notes = notesCtrl.text.trim();
                final sellPrice = double.tryParse(sellPriceCtrl.text);

                if (name.isEmpty) return;

                _editAsset(
                  asset,
                  name: name,
                  category: category,
                  buyPrice: buyPrice,
                  quantity: quantity,
                  currentPrice: currentPrice,
                  purchaseDate: purchaseDate,
                  notes: notes,
                  isSold: isSold,
                  sellPrice: sellPrice,
                  sellDate: sellDate ?? DateTime.now(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Render Helpers ──

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    // Filter holdings list by search & active/sold tab status
    final displayAssets = _assets.where((a) {
      final matchesSearch = a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTab = _activeTab == 'Active' ? !a.isSold : a.isSold;
      return matchesSearch && matchesTab;
    }).toList();

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildHeader(tokens),
              const SizedBox(height: 16),

              // ── Main Content Scrollable Area ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // ── Top KPIs Row ──
                      _buildTopKpisRow(tokens),
                      const SizedBox(height: 16),



                      // ── Split View (Donut Chart & Holdings List) ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Donut Chart
                          Expanded(
                            flex: 4,
                            child: _buildDonutChartCard(tokens),
                          ),
                          const SizedBox(width: 16),
                          // Right side: Holdings Manager
                          Expanded(
                            flex: 6,
                            child: _buildHoldingsManager(displayAssets, tokens),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeTokens tokens) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: tokens.textPrimary),
          onPressed: widget.onBack,
          splashRadius: 20,
          tooltip: 'Back to Tools',
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Tracker',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Track active holdings, realized returns, interest, and allocation',
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  // ── KPI Cards Row ──
  Widget _buildTopKpisRow(ThemeTokens tokens) {
    final invStr = _formatCurrency(_totalInvested);
    final curStr = _formatCurrency(_totalCurrentValue);
    final realisedStr = _formatPL(_realisedPL);
    final unrealisedStr = _formatPL(_unrealisedPL);
    final netStr = _formatPL(_netPL);

    final realisedPct = _totalInvested > 0 ? (_realisedPL / _totalInvested * 100) : 0.0;
    final unrealisedPct = _totalInvested > 0 ? (_unrealisedPL / _totalInvested * 100) : 0.0;
    final netPct = _totalInvested > 0 ? (_netPL / _totalInvested * 100) : 0.0;

    return Row(
      children: [
        _kpiCard('INVESTED', invStr, null, null, tokens),
        const SizedBox(width: 10),
        _kpiCard('CURRENT', curStr, null, null, tokens),
        const SizedBox(width: 10),
        _kpiCard(
          'REALISED P&L',
          realisedStr,
          realisedPct,
          _realisedPL >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          tokens,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          'UNREALISED P&L',
          unrealisedStr,
          unrealisedPct,
          _unrealisedPL >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          tokens,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          'NET P&L',
          netStr,
          netPct,
          _netPL >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          tokens,
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String mainVal, double? pct, Color? badgeColor, ThemeTokens tokens) {
    final accentColor = badgeColor ?? tokens.accent;
    final isColored = badgeColor != null;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.surface,
              isColored
                  ? accentColor.withValues(alpha: 0.04)
                  : tokens.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.borderSubtle, width: 0.8),
          boxShadow: [
            if (isColored)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: Container(
                  color: accentColor.withValues(alpha: 0.7),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 17, right: 14, top: 14, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mainVal,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: badgeColor ?? tokens.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    if (pct != null && badgeColor != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 9,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Donut Chart Card ──
  Widget _buildDonutChartCard(ThemeTokens tokens) {
    final activeAssets = _assets.where((a) => !a.isSold).toList();

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allocation',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
              ),
              if (_chartView == 'Subcategory')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _chartView = 'Category';
                      _touchedChartIndex = -1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 10, color: tokens.accent),
                        const SizedBox(width: 4),
                        Text('Back to Category', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: tokens.accent)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Toggles row
          Row(
            children: [
              _chartToggleBtn('Category', tokens),
              const SizedBox(width: 4),
              _chartToggleBtn('Name', tokens),
              const SizedBox(width: 4),
              _chartToggleBtn('Subcategory', tokens),
              if (_chartView == 'Subcategory') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubcategory,
                        dropdownColor: tokens.surface,
                        isDense: true,
                        style: TextStyle(color: tokens.textPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedSubcategory = val;
                              _touchedChartIndex = -1;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Pie Chart Render
          if (activeAssets.isEmpty)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 44, color: tokens.textMuted),
                  const SizedBox(height: 8),
                  Text('No active holdings to display allocation chart', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedChartIndex = -1;
                              return;
                            }
                            _touchedChartIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            
                            if (event is FlTapUpEvent) {
                              _handleChartClick(_touchedChartIndex, activeAssets);
                            }
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildChartSections(activeAssets, tokens),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _chartView,
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: tokens.textMuted),
                      ),
                      Text(
                        'Allocation',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Chart Legend
            _buildChartLegend(activeAssets, tokens),
          ],
        ],
      ),
    );
  }

  Widget _chartToggleBtn(String mode, ThemeTokens tokens) {
    final isActive = _chartView == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chartView = mode;
          _touchedChartIndex = -1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? tokens.accent.withValues(alpha: 0.15) : tokens.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? tokens.accent : tokens.borderSubtle),
        ),
        child: Text(
          mode,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? tokens.accent : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  void _handleChartClick(int index, List<PortfolioAsset> activeAssets) {
    if (index < 0) return;

    if (_chartView == 'Category') {
      // Find category of the clicked section
      final categoryWeights = _getCategoryAllocation(activeAssets);
      if (index < categoryWeights.keys.length) {
        final category = categoryWeights.keys.elementAt(index);
        setState(() {
          _chartView = 'Subcategory';
          _selectedSubcategory = category;
          _touchedChartIndex = -1;
        });
      }
    }
  }

  Map<String, double> _getCategoryAllocation(List<PortfolioAsset> activeAssets) {
    final map = <String, double>{};
    for (final a in activeAssets) {
      map[a.category] = (map[a.category] ?? 0.0) + a.currentValue;
    }
    return map;
  }

  List<PieChartSectionData> _buildChartSections(List<PortfolioAsset> activeAssets, ThemeTokens tokens) {
    final totalVal = _totalCurrentValue;
    if (totalVal <= 0) return [];

    if (_chartView == 'Category') {
      final map = _getCategoryAllocation(activeAssets);
      int idx = 0;
      return map.entries.map((entry) {
        final isTouched = idx == _touchedChartIndex;
        final radius = isTouched ? 34.0 : 28.0;
        final pct = (entry.value / totalVal) * 100;
        final section = PieChartSectionData(
          value: pct,
          color: _getChartColor(idx++),
          radius: radius,
          title: '${pct.toStringAsFixed(0)}%',
          titleStyle: TextStyle(
            fontSize: isTouched ? 10 : 8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
        return section;
      }).toList();
    } else if (_chartView == 'Name') {
      int idx = 0;
      return activeAssets.map((a) {
        final isTouched = idx == _touchedChartIndex;
        final radius = isTouched ? 34.0 : 28.0;
        final pct = (a.currentValue / totalVal) * 100;
        final section = PieChartSectionData(
          value: pct,
          color: _getChartColor(idx++),
          radius: radius,
          title: '${pct.toStringAsFixed(0)}%',
          titleStyle: TextStyle(
            fontSize: isTouched ? 10 : 8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
        return section;
      }).toList();
    } else {
      // Subcategory view
      final subAssets = activeAssets.where((a) => a.category == _selectedSubcategory).toList();
      final subTotal = subAssets.fold(0.0, (s, a) => s + a.currentValue);
      if (subTotal <= 0) return [];

      int idx = 0;
      return subAssets.map((a) {
        final isTouched = idx == _touchedChartIndex;
        final radius = isTouched ? 34.0 : 28.0;
        final pct = (a.currentValue / subTotal) * 100;
        final section = PieChartSectionData(
          value: pct,
          color: _getChartColor(idx++),
          radius: radius,
          title: '${pct.toStringAsFixed(0)}%',
          titleStyle: TextStyle(
            fontSize: isTouched ? 10 : 8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
        return section;
      }).toList();
    }
  }

  Widget _buildChartLegend(List<PortfolioAsset> activeAssets, ThemeTokens tokens) {
    if (_chartView == 'Category') {
      final map = _getCategoryAllocation(activeAssets);
      final total = _totalCurrentValue;
      int idx = 0;
      return Column(
        children: map.entries.map((entry) {
          final color = _getChartColor(idx++);
          final pct = total > 0 ? (entry.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.key, style: TextStyle(fontSize: 10, color: tokens.textSecondary), overflow: TextOverflow.ellipsis),
                ),
                Text('${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              ],
            ),
          );
        }).toList(),
      );
    } else if (_chartView == 'Name') {
      final total = _totalCurrentValue;
      int idx = 0;
      return Column(
        children: activeAssets.map((a) {
          final color = _getChartColor(idx++);
          final pct = total > 0 ? (a.currentValue / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.name, style: TextStyle(fontSize: 10, color: tokens.textSecondary), overflow: TextOverflow.ellipsis),
                ),
                Text('${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      // Subcategory Legend
      final subAssets = activeAssets.where((a) => a.category == _selectedSubcategory).toList();
      final subTotal = subAssets.fold(0.0, (s, a) => s + a.currentValue);
      if (subAssets.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('No active holdings in $_selectedSubcategory', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
          ),
        );
      }
      int idx = 0;
      return Column(
        children: subAssets.map((a) {
          final color = _getChartColor(idx++);
          final pct = subTotal > 0 ? (a.currentValue / subTotal * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.name, style: TextStyle(fontSize: 10, color: tokens.textSecondary), overflow: TextOverflow.ellipsis),
                ),
                Text('${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  Color _getChartColor(int idx) {
    const list = [
      Color(0xFF3F51B5), // Indigo
      Color(0xFF8E24AA), // Deep Purple
      Color(0xFFE91E63), // Pink
      Color(0xFF00ACC1), // Cyan
      Color(0xFFFFB300), // Amber
      Color(0xFF43A047), // Dark Green
      Color(0xFFF4511E), // Deep Orange
      Color(0xFF00897B), // Teal
      Color(0xFF3949AB), // Blue
      Color(0xFFD81B60), // Crimson
    ];
    return list[idx % list.length];
  }

  // ── Holdings Manager (Right Panel) ──
  Widget _buildHoldingsManager(List<PortfolioAsset> displayAssets, ThemeTokens tokens) {
    return Column(
      children: [
        // Tabs & Add button row
        Row(
          children: [
            _tabHeaderBtn('Active', tokens),
            const SizedBox(width: 8),
            _tabHeaderBtn('Closed / Sold', tokens),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _showAddForm = !_showAddForm;
                });
              },
              icon: Icon(_showAddForm ? Icons.close_rounded : Icons.add_rounded, size: 14),
              label: Text(_showAddForm ? 'Close Form' : 'Buy Transaction', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Add Transaction Form
        if (_showAddForm) ...[
          _buildAddTransactionForm(tokens),
          const SizedBox(height: 12),
        ],

        // Search and Filter Bar
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 16, color: tokens.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: TextStyle(fontSize: 12, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by symbol, name, or category...',
                    hintStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Display List
        SizedBox(
          height: 350,
          child: displayAssets.isEmpty
              ? EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: _assets.isEmpty
                      ? 'No transactions recorded yet'
                      : 'No transactions match search criteria',
                  subtitle: _assets.isEmpty ? 'Tap "Buy Transaction" to record your first asset purchase' : null,
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayAssets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final asset = displayAssets[idx];
                    return _buildAssetRowCard(asset, tokens);
                  },
                ),
        ),
      ],
    );
  }

  Widget _tabHeaderBtn(String tab, ThemeTokens tokens) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? tokens.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          tab,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? tokens.textPrimary : tokens.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildAddTransactionForm(ThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record Purchase', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _formTextField(_nameCtrl, 'Asset Name (e.g. MSFT)', tokens)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: tokens.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      dropdownColor: tokens.surface,
                      isDense: true,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 11),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _formTextField(_buyPriceCtrl, 'Buy Price (\$)', tokens, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _formTextField(_quantityCtrl, 'Quantity', tokens, isNum: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _formTextField(_currentPriceCtrl, 'Current Price (defaults to buy)', tokens, isNum: true)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: tokens.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(fontSize: 11, color: tokens.textPrimary),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.calendar_today_rounded, size: 14, color: tokens.accent),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _formTextField(_notesCtrl, 'Notes (optional)', tokens),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAddForm = false;
                    _clearForm();
                  });
                },
                child: Text('Cancel', style: TextStyle(color: tokens.textMuted, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _addAssetTransaction,
                child: const Text('Add to Portfolio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetRowCard(PortfolioAsset asset, ThemeTokens tokens) {
    final isProfit = asset.profitLoss >= 0;
    final statusColor = isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final plPct = asset.profitLossPercent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            statusColor.withValues(alpha: 0.05),
            tokens.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Left accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(
                color: statusColor.withValues(alpha: 0.8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 17, right: 14, top: 12, bottom: 12),
              child: Row(
                children: [
                  // Name and Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              asset.name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tokens.accent.withValues(alpha: 0.15)),
                              ),
                              child: Text(
                                asset.category,
                                style: TextStyle(fontSize: 8, color: tokens.accent, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${asset.buyPrice.toStringAsFixed(2)} × ${asset.quantity.toStringAsFixed(2)}  ·  ${asset.purchaseDate.day}/${asset.purchaseDate.month}/${asset.purchaseDate.year}',
                          style: TextStyle(fontSize: 9, color: tokens.textSecondary, letterSpacing: 0.1),
                        ),
                        if (asset.notes.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            asset.notes,
                            style: TextStyle(fontSize: 9, color: tokens.textSecondary, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // P&L Metrics
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!asset.isSold) ...[
                        Text(
                          _formatCurrency(asset.currentValue),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                size: 9,
                                color: statusColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${_formatPL(asset.profitLoss)} (${plPct.toStringAsFixed(1)}%)',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CLOSED',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: tokens.textMuted, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isProfit ? '+' : ''}\$${_formatCurrency(asset.profitLoss)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Actions Menu
                  _buildAssetActionsMenu(asset, tokens),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetActionsMenu(PortfolioAsset asset, ThemeTokens tokens) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: tokens.textMuted),
      color: tokens.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size.zero),
      ),
      onSelected: (action) {
        if (action == 'edit') {
          _showEditDialog(asset, tokens);
        } else if (action == 'sell') {
          _showSellDialog(asset, tokens);
        } else if (action == 'delete') {
          _deleteAsset(asset.id);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 14, color: tokens.textPrimary),
              const SizedBox(width: 8),
              Text('Edit Details', style: TextStyle(color: tokens.textPrimary, fontSize: 12)),
            ],
          ),
        ),
        if (!asset.isSold)
          PopupMenuItem(
            value: 'sell',
            child: Row(
              children: [
                Icon(Icons.monetization_on_outlined, size: 14, color: tokens.textPrimary),
                const SizedBox(width: 8),
                Text('Sell / Close', style: TextStyle(color: tokens.textPrimary, fontSize: 12)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 14, color: const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // ── General Utility Formatters ──

  String _formatCurrency(double val) {
    return '\$${_formatNumber(val)}';
  }

  String _formatPL(double val) {
    final prefix = val >= 0 ? '+' : '-';
    return '$prefix\$${_formatNumber(val.abs())}';
  }

  String _formatNumber(double val) {
    if (val.abs() >= 1000000.0) {
      return '${(val / 1000000.0).toStringAsFixed(2)}M';
    } else if (val.abs() >= 1000.0) {
      return '${(val / 1000.0).toStringAsFixed(1)}K';
    } else {
      return val.toStringAsFixed(2);
    }
  }

  Widget _formTextField(TextEditingController ctrl, String hint, ThemeTokens tokens, {bool isNum = false}) {
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
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
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

  Widget _dialogTextField(TextEditingController ctrl, String label, ThemeTokens tokens, {bool isNum = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
      ),
    );
  }
}
