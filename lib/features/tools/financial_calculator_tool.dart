import 'dart:math';
import 'package:flutter/material.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_button.dart';

// ──────────────────────────────────────────────
// Financial Calculator — Full Page Tool
// 9 Tabs: Cash Flow, Bonds, Amortization, Stats,
//         Depreciation, Breakeven, Dates, Currency, Advanced
// ──────────────────────────────────────────────

enum FinCalcTab {
  cashFlow,
  bonds,
  amortization,
  statistics,
  depreciation,
  breakeven,
  dateFunctions,
  currencyPercent,
  advancedInvestment,
}

class FinancialCalculatorPage extends StatefulWidget {
  final VoidCallback onBack;
  const FinancialCalculatorPage({super.key, required this.onBack});

  @override
  State<FinancialCalculatorPage> createState() => _FinancialCalculatorPageState();
}

class _FinancialCalculatorPageState extends State<FinancialCalculatorPage> {
  FinCalcTab _activeTab = FinCalcTab.cashFlow;

  // ── Cash Flow State ──
  double _cf0 = 0.0;
  final List<_CashFlowItem> _cashFlows = []; // amount, frequency
  double _cfRate = 10.0;
  double _reinvestmentRate = 10.0; // for MIRR
  String _cfResult = '';

  // ── Bond State ──
  final _bondFaceCtrl = TextEditingController(text: '1000');
  final _bondCouponCtrl = TextEditingController(text: '5');
  final _bondYieldCtrl = TextEditingController(text: '4');
  final _bondYearsCtrl = TextEditingController(text: '10');
  int _bondFreq = 2; // semi-annual
  String _bondResult = '';

  // ── Amortization State ──
  final _amortLoanCtrl = TextEditingController(text: '500000');
  final _amortRateCtrl = TextEditingController(text: '6');
  final _amortTermCtrl = TextEditingController(text: '30');
  int _amortFreq = 12;
  String _amortResult = '';
  List<_AmortRow> _amortSchedule = [];
  bool _showAmortSchedule = false;

  // ── Statistics State ──
  final _statsInputCtrl = TextEditingController(text: '10,20,30,40,50');
  String _statsResult = '';

  // ── Depreciation State ──
  final _depCostCtrl = TextEditingController(text: '50000');
  final _depSalvageCtrl = TextEditingController(text: '5000');
  final _depLifeCtrl = TextEditingController(text: '5');
  String _depResult = '';
  List<_DepRow> _depSchedule = [];
  bool _showDepSchedule = false;

  // ── Breakeven State ──
  final _beFixedCtrl = TextEditingController(text: '50000');
  final _beVarCtrl = TextEditingController(text: '30');
  final _bePriceCtrl = TextEditingController(text: '100');
  String _beResult = '';

  // ── Date Functions State ──
  DateTime _date1 = DateTime.now();
  DateTime _date2 = DateTime.now().add(const Duration(days: 90));
  String _dateConvention = 'Actual/365';
  String _dateResult = '';

  // ── Currency & Percentage State ──
  String _currPctTab = 'pct_change'; // pct_change, markup, margin, discount
  final _pctOldCtrl = TextEditingController(text: '100');
  final _pctNewCtrl = TextEditingController(text: '150');
  final _markupCostCtrl = TextEditingController(text: '50');
  final _markupPctCtrl = TextEditingController(text: '20');
  final _marginCostCtrl = TextEditingController(text: '80');
  final _marginPctCtrl = TextEditingController(text: '25');
  final _discPriceCtrl = TextEditingController(text: '200');
  final _discPctCtrl = TextEditingController(text: '15');
  String _currPctResult = '';

  // ── Advanced Investment State ──
  String _advTab = 'cagr'; // cagr, hpr, ear, nominal_effective
  final _cagrBeginCtrl = TextEditingController(text: '10000');
  final _cagrEndCtrl = TextEditingController(text: '18000');
  final _cagrYearsCtrl = TextEditingController(text: '5');
  final _hprBeginCtrl = TextEditingController(text: '10000');
  final _hprEndCtrl = TextEditingController(text: '12000');
  final _hprIncomeCtrl = TextEditingController(text: '500');
  final _earNominalCtrl = TextEditingController(text: '8');
  final _earPeriodsCtrl = TextEditingController(text: '12');
  final _nomEffNominalCtrl = TextEditingController(text: '8');
  final _nomEffPeriodsCtrl = TextEditingController(text: '12');
  bool _nomEffToEffective = true;
  String _advResult = '';

  // ── Date Pickers ──
  Future<void> _pickDate(bool isFirst) async {
    final initial = isFirst ? _date1 : _date2;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFirst) _date1 = picked;
        else _date2 = picked;
        _dateResult = '';
      });
    }
  }

  @override
  void dispose() {
    _bondFaceCtrl.dispose();
    _bondCouponCtrl.dispose();
    _bondYieldCtrl.dispose();
    _bondYearsCtrl.dispose();
    _amortLoanCtrl.dispose();
    _amortRateCtrl.dispose();
    _amortTermCtrl.dispose();
    _statsInputCtrl.dispose();
    _depCostCtrl.dispose();
    _depSalvageCtrl.dispose();
    _depLifeCtrl.dispose();
    _beFixedCtrl.dispose();
    _beVarCtrl.dispose();
    _bePriceCtrl.dispose();
    _pctOldCtrl.dispose();
    _pctNewCtrl.dispose();
    _markupCostCtrl.dispose();
    _markupPctCtrl.dispose();
    _marginCostCtrl.dispose();
    _marginPctCtrl.dispose();
    _discPriceCtrl.dispose();
    _discPctCtrl.dispose();
    _cagrBeginCtrl.dispose();
    _cagrEndCtrl.dispose();
    _cagrYearsCtrl.dispose();
    _hprBeginCtrl.dispose();
    _hprEndCtrl.dispose();
    _hprIncomeCtrl.dispose();
    _earNominalCtrl.dispose();
    _earPeriodsCtrl.dispose();
    _nomEffNominalCtrl.dispose();
    _nomEffPeriodsCtrl.dispose();
    super.dispose();
  }

  String _fmt(double n) {
    if (n.isNaN || n.isInfinite) return 'Error';
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  String _fmtMoney(double n) {
    if (n.isNaN || n.isInfinite) return 'Error';
    final abs = n.abs();
    String val;
    if (abs >= 1e7) val = '${(n / 1e7).toStringAsFixed(2)}Cr';
    else if (abs >= 1e5) val = '${(n / 1e5).toStringAsFixed(2)}L';
    else val = n.toStringAsFixed(2);
    return n < 0 ? '-\$${val.substring(1)}' : '\$${val}';
  }

  // ═══════════════════════════════════════
  // 1. CASH FLOW (NPV / IRR / MIRR)
  // ═══════════════════════════════════════

  void _computeNPV() {
    if (_cashFlows.isEmpty) {
      setState(() => _cfResult = 'Add at least one cash flow');
      return;
    }
    final r = _cfRate / 100.0;
    double npv = _cf0;
    int t = 1;
    for (final cf in _cashFlows) {
      for (int i = 0; i < cf.frequency; i++) {
        npv += cf.amount / pow(1 + r, t);
        t++;
      }
    }
    setState(() => _cfResult = 'NPV: ${_fmtMoney(npv)}');
  }

  void _computeIRR() {
    bool hasPos = _cf0 > 0, hasNeg = _cf0 < 0;
    for (final cf in _cashFlows) {
      if (cf.amount > 0) hasPos = true;
      if (cf.amount < 0) hasNeg = true;
    }
    if (!hasPos || !hasNeg) {
      setState(() => _cfResult = 'IRR: Need both +/− cash flows');
      return;
    }

    double eval(double rate) {
      double npv = _cf0;
      int t = 1;
      for (final cf in _cashFlows) {
        for (int i = 0; i < cf.frequency; i++) {
          npv += cf.amount / pow(1 + rate, t);
          t++;
        }
      }
      return npv;
    }

    double r0 = 0.05, r1 = 0.12;
    double f0 = eval(r0), f1 = eval(r1);
    for (int i = 0; i < 150; i++) {
      if ((f1 - f0).abs() < 1e-12) break;
      double rNext = r1 - f1 * (r1 - r0) / (f1 - f0);
      rNext = rNext.clamp(-0.99, 12.0);
      r0 = r1; f0 = f1;
      r1 = rNext; f1 = eval(r1);
      if (f1.abs() < 1e-8) break;
    }
    if (f1.abs() > 1e-4) {
      setState(() => _cfResult = 'IRR: Does not converge');
    } else {
      setState(() => _cfResult = 'IRR: ${_fmt(r1 * 100)}%');
    }
  }

  void _computeMIRR() {
    if (_cashFlows.isEmpty) {
      setState(() => _cfResult = 'Add at least one cash flow');
      return;
    }
    final fr = _cfRate / 100.0;      // finance rate
    final rr = _reinvestmentRate / 100.0; // reinvestment rate

    // PV of negative cash flows discounted at finance rate
    double pvNeg = 0;
    if (_cf0 < 0) pvNeg += _cf0; // CF0 at t=0
    // Actually CF0 is at t=0, so it's already at present value
    pvNeg = _cf0 < 0 ? _cf0 : 0;

    int period = 1;
    for (final cf in _cashFlows) {
      for (int i = 0; i < cf.frequency; i++) {
        if (cf.amount < 0) {
          pvNeg += cf.amount / pow(1 + fr, period);
        }
        period++;
      }
    }

    // FV of positive cash flows compounded at reinvestment rate
    double fvPos = 0;
    period = 1;
    for (final cf in _cashFlows) {
      for (int i = 0; i < cf.frequency; i++) {
        if (cf.amount > 0) {
          fvPos += cf.amount * pow(1 + rr, period);
        }
        period++;
      }
    }

    if (pvNeg >= 0 || fvPos <= 0) {
      setState(() => _cfResult = 'MIRR: Need both +/− cash flows');
      return;
    }

    final totalPeriods = _cashFlows.fold<int>(0, (s, cf) => s + cf.frequency);
    final mirr = (pow(fvPos / -pvNeg, 1.0 / totalPeriods) - 1).toDouble();
    setState(() => _cfResult = 'MIRR: ${_fmt(mirr * 100)}%');
  }

  // ═══════════════════════════════════════
  // 2. BOND CALCULATIONS
  // ═══════════════════════════════════════

  void _computeBond() {
    final face = double.tryParse(_bondFaceCtrl.text) ?? 0;
    final couponRate = double.tryParse(_bondCouponCtrl.text) ?? 0;
    final ytm = double.tryParse(_bondYieldCtrl.text) ?? 0;
    final years = double.tryParse(_bondYearsCtrl.text) ?? 0;

    if (face <= 0 || couponRate <= 0 || years <= 0) {
      setState(() => _bondResult = 'Invalid inputs');
      return;
    }

    final n = (years * _bondFreq).round();
    final r = (ytm / 100.0) / _bondFreq;
    final coupon = face * (couponRate / 100.0) / _bondFreq;

    // Bond Price
    double price;
    if (r > 0) {
      price = coupon * (1 - pow(1 + r, -n)) / r + face / pow(1 + r, n);
    } else {
      price = face;
    }

    // Current Yield
    final annualCoupon = face * (couponRate / 100.0);
    final currentYield = price > 0 ? (annualCoupon / price) * 100 : 0.0;

    // Macaulay Duration
    double macDur = 0;
    double pvTotal = 0;
    for (int i = 1; i <= n; i++) {
      final pv = coupon / pow(1 + r, i);
      macDur += i * pv;
      pvTotal += pv;
    }
    macDur += n * (face / pow(1 + r, n));
    pvTotal += face / pow(1 + r, n);
    macDur = pvTotal > 0 ? macDur / pvTotal : 0;

    // Modified Duration
    final modDur = r > 0 ? macDur / (1 + r) : macDur;
    final yearsDur = macDur / _bondFreq;

    // Convexity
    double convexity = 0;
    for (int i = 1; i <= n; i++) {
      final pv = coupon / pow(1 + r, i);
      convexity += i * (i + 1) * pv;
    }
    convexity += n * (n + 1) * (face / pow(1 + r, n));
    convexity = pvTotal > 0 ? convexity / (pvTotal * pow(1 + r, 2)) : 0;
    convexity = convexity / (_bondFreq * _bondFreq); // annualize

    setState(() {
      _bondResult = 'Bond Price: ${_fmtMoney(price)}'
          '\nCurrent Yield: ${_fmt(currentYield)}%'
          '\nMacaulay Duration: ${_fmt(yearsDur)} yrs'
          '\nModified Duration: ${_fmt(modDur)}'
          '\nConvexity: ${_fmt(convexity)}';
    });
  }

  // ═══════════════════════════════════════
  // 3. AMORTIZATION
  // ═══════════════════════════════════════

  void _computeAmortization() {
    final loan = double.tryParse(_amortLoanCtrl.text) ?? 0;
    final rate = double.tryParse(_amortRateCtrl.text) ?? 0;
    final term = double.tryParse(_amortTermCtrl.text) ?? 0;

    if (loan <= 0 || rate <= 0 || term <= 0) {
      setState(() => _amortResult = 'Invalid inputs');
      return;
    }

    final n = (term * _amortFreq).round();
    final r = (rate / 100.0) / _amortFreq;

    double payment;
    if (r > 0) {
      payment = loan * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
    } else {
      payment = loan / n;
    }

    final schedule = <_AmortRow>[];
    double balance = loan;
    double totalInterest = 0;

    for (int i = 1; i <= n && balance > 0.01; i++) {
      final interest = balance * r;
      double principal = payment - interest;
      if (principal > balance) principal = balance;
      balance -= principal;
      if (balance < 0) balance = 0;
      totalInterest += interest;
      schedule.add(_AmortRow(period: i, payment: payment, principal: principal, interest: interest, balance: balance));
    }

    final totalPayment = payment * n;
    setState(() {
      _amortSchedule = schedule;
      _showAmortSchedule = true;
      _amortResult = 'Monthly Payment: ${_fmtMoney(payment)}'
          '\nTotal Interest: ${_fmtMoney(totalInterest)}'
          '\nTotal Payment: ${_fmtMoney(totalPayment)}'
          '\nRemaining Balance (after ${_amortSchedule.length} payments): ${_fmtMoney(balance)}';
    });
  }

  // ═══════════════════════════════════════
  // 4. STATISTICS
  // ═══════════════════════════════════════

  void _computeStats() {
    final parts = _statsInputCtrl.text
        .split(RegExp(r'[,\s]+'))
        .map((s) => double.tryParse(s.trim()))
        .whereType<double>()
        .toList();

    if (parts.length < 2) {
      setState(() => _statsResult = 'Enter at least 2 numbers');
      return;
    }

    final n = parts.length;
    final sum = parts.fold(0.0, (a, b) => a + b);
    final mean = sum / n;

    final sorted = List<double>.from(parts)..sort();
    final median = n % 2 == 1
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;

    final variance = parts.fold(0.0, (s, v) => s + pow(v - mean, 2)) / (n - 1);
    final stdDev = sqrt(variance);

    final minVal = sorted.first;
    final maxVal = sorted.last;
    final range = maxVal - minVal;

    setState(() {
      _statsResult = 'Count: $n'
          '\nMean: ${_fmt(mean)}'
          '\nMedian: ${_fmt(median)}'
          '\nStd Deviation: ${_fmt(stdDev)}'
          '\nVariance: ${_fmt(variance)}'
          '\nMin: ${_fmt(minVal)}'
          '\nMax: ${_fmt(maxVal)}'
          '\nRange: ${_fmt(range)}';
    });
  }

  // ═══════════════════════════════════════
  // 5. DEPRECIATION
  // ═══════════════════════════════════════

  void _computeDepreciation() {
    final cost = double.tryParse(_depCostCtrl.text) ?? 0;
    final salvage = double.tryParse(_depSalvageCtrl.text) ?? 0;
    final life = double.tryParse(_depLifeCtrl.text)?.roundToDouble() ?? 0;

    if (cost <= 0 || life <= 0) {
      setState(() => _depResult = 'Invalid inputs');
      return;
    }

    final depreciableBase = cost - salvage;
    final slExpense = depreciableBase / life;

    // Straight-Line
    final slRows = <_DepRow>[];
    for (int y = 1; y <= life.round(); y++) {
      final accum = (y * slExpense).clamp(0.0, depreciableBase);
      final bookVal = cost - accum;
      slRows.add(_DepRow(year: y, expense: slExpense, accumulated: accum, bookValue: bookVal));
    }

    // Double-Declining Balance
    final ddbRows = <_DepRow>[];
    double ddbBalance = cost;
    double ddbAccum = 0;
    const ddbRate = 2.0;
    for (int y = 1; y <= life.round(); y++) {
      double expense = (ddbBalance * (ddbRate / life)).clamp(0.0, depreciableBase - ddbAccum);
      if (y == life.round()) expense = depreciableBase - ddbAccum;
      ddbAccum += expense;
      ddbBalance = cost - ddbAccum;
      if (ddbBalance < salvage) ddbBalance = salvage;
      ddbRows.add(_DepRow(year: y, expense: expense, accumulated: ddbAccum, bookValue: ddbBalance));
    }

    // Sum-of-the-Years-Digits
    final sydRows = <_DepRow>[];
    final sydSum = life * (life + 1) / 2;
    double sydAccum = 0;
    for (int y = 1; y <= life.round(); y++) {
      final remainingLife = life - y + 1;
      double expense = depreciableBase * (remainingLife / sydSum);
      sydAccum += expense;
      final bookVal = cost - sydAccum;
      sydRows.add(_DepRow(year: y, expense: expense, accumulated: sydAccum, bookValue: bookVal));
    }

    setState(() {
      _depSchedule = [
        ...slRows.map((r) => _DepRow(year: r.year, expense: r.expense, accumulated: r.accumulated, bookValue: r.bookValue, method: 'SL')),
        ...ddbRows.map((r) => _DepRow(year: r.year, expense: r.expense, accumulated: r.accumulated, bookValue: r.bookValue, method: 'DDB')),
        ...sydRows.map((r) => _DepRow(year: r.year, expense: r.expense, accumulated: r.accumulated, bookValue: r.bookValue, method: 'SYD')),
      ];
      _showDepSchedule = true;
      _depResult = 'Straight-Line: ${_fmtMoney(slExpense)}/yr'
          '\nDDB Yr 1: ${_fmtMoney(ddbRows.isNotEmpty ? ddbRows[0].expense : 0.0)}'
          '\nSYD Yr 1: ${_fmtMoney(sydRows.isNotEmpty ? sydRows[0].expense : 0.0)}';
    });
  }

  // ═══════════════════════════════════════
  // 6. BREAKEVEN ANALYSIS
  // ═══════════════════════════════════════

  void _computeBreakeven() {
    final fixedCost = double.tryParse(_beFixedCtrl.text) ?? 0;
    final varCost = double.tryParse(_beVarCtrl.text) ?? 0;
    final price = double.tryParse(_bePriceCtrl.text) ?? 0;

    if (price <= varCost) {
      setState(() => _beResult = 'Price must exceed variable cost per unit');
      return;
    }

    final contribMargin = price - varCost;
    final beUnits = fixedCost / contribMargin;
    final beRevenue = beUnits * price;

    setState(() {
      _beResult = 'Contribution Margin: ${_fmtMoney(contribMargin)}/unit'
          '\nContribution Margin Ratio: ${_fmt(contribMargin / price * 100)}%'
          '\nBreakeven Units: ${beUnits.ceil()} units'
          '\nBreakeven Revenue: ${_fmtMoney(beRevenue)}';
    });
  }

  // ═══════════════════════════════════════
  // 7. DATE FUNCTIONS
  // ═══════════════════════════════════════

  int _daysBetween(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return bDate.difference(aDate).inDays.abs();
  }

  double _dayCountFraction(DateTime d1, DateTime d2, String convention) {
    final days = _daysBetween(d1, d2).toDouble();
    switch (convention) {
      case '30/360':
        final y1 = d1.year, m1 = d1.month, day1 = min(d1.day, 30);
        final y2 = d2.year, m2 = d2.month, day2 = min(d2.day, 30);
        return ((y2 - y1) * 360 + (m2 - m1) * 30 + (day2 - day1)) / 360.0;
      case 'Actual/360':
        return days / 360.0;
      case 'Actual/365':
        return days / 365.0;
      case 'Actual/Actual':
        // Simplified: use average year length
        return days / 365.25;
      default:
        return days / 365.0;
    }
  }

  void _computeDateFunctions() {
    final days = _daysBetween(_date1, _date2);
    final fraction = _dayCountFraction(_date1, _date2, _dateConvention);

    final fmtD = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    setState(() {
      _dateResult = 'Date 1: ${fmtD(_date1)}'
          '\nDate 2: ${fmtD(_date2)}'
          '\nDays Between: $days'
          '\nDay Count ($_dateConvention): ${_fmt(fraction)}';
    });
  }

  // ═══════════════════════════════════════
  // 8. CURRENCY & PERCENTAGE
  // ═══════════════════════════════════════

  void _computeCurrencyPct() {
    switch (_currPctTab) {
      case 'pct_change': {
        final oldV = double.tryParse(_pctOldCtrl.text) ?? 0;
        final newV = double.tryParse(_pctNewCtrl.text) ?? 0;
        if (oldV == 0) {
          setState(() => _currPctResult = 'Old value cannot be zero');
          return;
        }
        final change = ((newV - oldV) / oldV) * 100;
        setState(() {
          _currPctResult = 'Change: ${_fmtMoney(newV - oldV)}'
              '\nPercentage Change: ${_fmt(change)}%';
        });
        break;
      }
      case 'markup': {
        final cost = double.tryParse(_markupCostCtrl.text) ?? 0;
        final pct = double.tryParse(_markupPctCtrl.text) ?? 0;
        final markup = cost * (pct / 100);
        final sellingPrice = cost + markup;
        final margin = sellingPrice > 0 ? (markup / sellingPrice) * 100 : 0.0;
        setState(() {
          _currPctResult = 'Markup Amount: ${_fmtMoney(markup)}'
              '\nSelling Price: ${_fmtMoney(sellingPrice)}'
              '\nMargin Percentage: ${_fmt(margin)}%';
        });
        break;
      }
      case 'margin': {
        final cost = double.tryParse(_marginCostCtrl.text) ?? 0;
        final pct = double.tryParse(_marginPctCtrl.text) ?? 0;
        final sellingPrice = cost / (1 - pct / 100);
        final profit = sellingPrice - cost;
        final markup = cost > 0 ? (profit / cost) * 100 : 0.0;
        setState(() {
          _currPctResult = 'Selling Price: ${_fmtMoney(sellingPrice)}'
              '\nProfit Amount: ${_fmtMoney(profit)}'
              '\nMarkup Percentage: ${_fmt(markup)}%';
        });
        break;
      }
      case 'discount': {
        final price = double.tryParse(_discPriceCtrl.text) ?? 0;
        final pct = double.tryParse(_discPctCtrl.text) ?? 0;
        final discount = price * (pct / 100);
        final finalPrice = price - discount;
        setState(() {
          _currPctResult = 'Discount Amount: ${_fmtMoney(discount)}'
              '\nFinal Price: ${_fmtMoney(finalPrice)}'
              '\nYou Save: ${pct.toStringAsFixed(1)}%';
        });
        break;
      }
    }
  }

  // ═══════════════════════════════════════
  // 9. ADVANCED INVESTMENT FUNCTIONS
  // ═══════════════════════════════════════

  void _computeAdvanced() {
    switch (_advTab) {
      case 'cagr': {
        final begin = double.tryParse(_cagrBeginCtrl.text) ?? 0;
        final end = double.tryParse(_cagrEndCtrl.text) ?? 0;
        final years = double.tryParse(_cagrYearsCtrl.text) ?? 1;
        if (begin <= 0 || years <= 0) {
          setState(() => _advResult = 'Invalid inputs');
          return;
        }
        final cagr = pow(end / begin, 1.0 / years) - 1;
        setState(() {
          _advResult = 'CAGR: ${_fmt(cagr * 100)}%'
              '\nTotal Return: ${_fmt((end - begin) / begin * 100)}%'
              '\nGain: ${_fmtMoney(end - begin)}';
        });
        break;
      }
      case 'hpr': {
        final begin = double.tryParse(_hprBeginCtrl.text) ?? 0;
        final end = double.tryParse(_hprEndCtrl.text) ?? 0;
        final income = double.tryParse(_hprIncomeCtrl.text) ?? 0;
        if (begin <= 0) {
          setState(() => _advResult = 'Beginning value must be > 0');
          return;
        }
        final hpr = ((end - begin + income) / begin) * 100;
        setState(() {
          _advResult = 'Holding Period Return: ${_fmt(hpr)}%'
              '\nCapital Gain: ${_fmtMoney(end - begin)}'
              '\nIncome: ${_fmtMoney(income)}'
              '\nTotal Gain: ${_fmtMoney(end - begin + income)}';
        });
        break;
      }
      case 'ear': {
        final nominal = double.tryParse(_earNominalCtrl.text) ?? 0;
        final periods = double.tryParse(_earPeriodsCtrl.text) ?? 1;
        if (periods <= 0) {
          setState(() => _advResult = 'Compounding periods must be > 0');
          return;
        }
        final ear = ((pow(1 + (nominal / 100) / periods, periods) - 1) * 100).toDouble();
        setState(() {
          _advResult = 'Nominal Rate: ${_fmt(nominal)}%'
              '\nCompounding: ${periods.toInt()}x/year'
              '\nEffective Annual Rate (EAR): ${_fmt(ear)}%';
        });
        break;
      }
      case 'nominal_effective': {
        final rate = double.tryParse(_nomEffNominalCtrl.text) ?? 0;
        final periods = double.tryParse(_nomEffPeriodsCtrl.text) ?? 1;
        if (periods <= 0) {
          setState(() => _advResult = 'Periods must be > 0');
          return;
        }
        if (_nomEffToEffective) {
          final ear = ((pow(1 + (rate / 100) / periods, periods) - 1) * 100).toDouble();
          setState(() => _advResult = 'Effective Rate: ${_fmt(ear)}%');
        } else {
          final nom = ((pow(1 + rate / 100, 1.0 / periods) - 1) * periods * 100).toDouble();
          setState(() => _advResult = 'Nominal Rate: ${_fmt(nom)}%');
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

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
                  tooltip: 'Back to Tools',
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Calculator',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: tokens.textPrimary, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NPV, IRR, Bonds, Amortization, Stats, Depreciation & more',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Tab Bar ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _tabBtn(FinCalcTab.cashFlow, 'Cash Flow', Icons.account_balance_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.bonds, 'Bonds', Icons.receipt_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.amortization, 'Amortization', Icons.percent_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.statistics, 'Statistics', Icons.bar_chart_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.depreciation, 'Depreciation', Icons.trending_down_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.breakeven, 'Breakeven', Icons.balance_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.dateFunctions, 'Dates', Icons.calendar_month_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.currencyPercent, 'Currency', Icons.monetization_on_rounded),
                  const SizedBox(width: 6),
                  _tabBtn(FinCalcTab.advancedInvestment, 'Advanced', Icons.show_chart_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Tab Content ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildTabContent(tokens),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(FinCalcTab tab, String label, IconData icon) {
    final tokens = FocusOsTheme.of(context);
    final active = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.accent.withValues(alpha: 0.12) : tokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? tokens.accent.withValues(alpha: 0.25) : tokens.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? tokens.accent : tokens.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeTokens tokens) {
    switch (_activeTab) {
      case FinCalcTab.cashFlow: return _buildCashFlowTab(tokens);
      case FinCalcTab.bonds: return _buildBondsTab(tokens);
      case FinCalcTab.amortization: return _buildAmortizationTab(tokens);
      case FinCalcTab.statistics: return _buildStatisticsTab(tokens);
      case FinCalcTab.depreciation: return _buildDepreciationTab(tokens);
      case FinCalcTab.breakeven: return _buildBreakevenTab(tokens);
      case FinCalcTab.dateFunctions: return _buildDateFunctionsTab(tokens);
      case FinCalcTab.currencyPercent: return _buildCurrencyPctTab(tokens);
      case FinCalcTab.advancedInvestment: return _buildAdvancedTab(tokens);
    }
  }

  // ──────────────────────────────────────────────
  // Helper widgets
  // ──────────────────────────────────────────────

  Widget _inputField({
    required ThemeTokens tokens,
    required String label,
    required TextEditingController controller,
    String? suffix,
    String? prefix,
    double? width,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          width: width ?? 140,
          height: 32,
          decoration: BoxDecoration(
            color: tokens.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (prefix != null)
                Text(prefix, style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w600)),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffix != null)
                Text(suffix, style: TextStyle(fontSize: 11, color: tokens.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultCard(ThemeTokens tokens, String result) {
    if (result.isEmpty) return const SizedBox.shrink();
    final isError = result.toLowerCase().contains('error') || result.toLowerCase().contains('invalid');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFEF4444).withValues(alpha: 0.06)
            : tokens.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
              : tokens.accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: result.split('\n').map((line) {
          final parts = line.split(': ');
          if (parts.length == 2) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(parts[0], style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                  Text(parts[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isError ? const Color(0xFFEF4444) : tokens.textPrimary, fontFamily: 'monospace')),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(line, style: TextStyle(fontSize: 12, color: isError ? const Color(0xFFEF4444) : tokens.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  Widget _computeBtn(ThemeTokens tokens, String label, VoidCallback onTap) {
    return PremiumButton(
      label: label,
      icon: Icons.calculate_rounded,
      variant: PremiumButtonVariant.gradient,
      onTap: onTap,
    );
  }

  // ═══════════════════════════════════════
  // 1. CASH FLOW TAB
  // ═══════════════════════════════════════

  Widget _buildCashFlowTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cash Flow Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Net Present Value, Internal Rate of Return & Modified IRR', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        Row(
          children: [
            _inputField(tokens: tokens, label: 'CF₀ (Initial Investment)', controller: TextEditingController.fromValue(TextEditingValue(text: _cf0.toString())), prefix: r'$', suffix: ''),
            const SizedBox(width: 16),
            _inputField(tokens: tokens, label: 'Discount Rate (I/Y %)', controller: TextEditingController.fromValue(TextEditingValue(text: _cfRate.toString())), suffix: '%'),
            const SizedBox(width: 16),
            _inputField(tokens: tokens, label: 'Reinvestment Rate %', controller: TextEditingController.fromValue(TextEditingValue(text: _reinvestmentRate.toString())), suffix: '%'),
          ],
        ),
        const SizedBox(height: 16),
        // Cash Flow list
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Periodic Cash Flows', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
            _addCfBtn(tokens),
          ],
        ),
        const SizedBox(height: 8),
        if (_cashFlows.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('No cash flows added yet. Tap "+ Add" to enter CF₁, CF₂...', style: TextStyle(fontSize: 12, color: tokens.textMuted))),
          )
        else
          ..._cashFlows.asMap().entries.map((entry) {
            final i = entry.key;
            final cf = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('CF${i + 1}', style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: TextEditingController.fromValue(TextEditingValue(text: cf.frequency.toString())),
                      decoration: InputDecoration(
                        hintText: 'Freq',
                        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        fillColor: tokens.background.withValues(alpha: 0.5), filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      ),
                      style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFamily: 'monospace'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => cf.frequency = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: const Color(0xFFEF4444)),
                    onPressed: () => setState(() => _cashFlows.removeAt(i)),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          _computeBtn(tokens, 'Compute NPV', _computeNPV),
          _computeBtn(tokens, 'Compute IRR', _computeIRR),
          _computeBtn(tokens, 'Compute MIRR', _computeMIRR),
        ]),
        _resultCard(tokens, _cfResult),
      ],
    );
  }

  Widget _addCfBtn(ThemeTokens tokens) {
    return GestureDetector(
      onTap: () => setState(() => _cashFlows.add(_CashFlowItem(amount: 0, frequency: 1))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: tokens.accent),
            const SizedBox(width: 4),
            Text('Add CF', style: TextStyle(fontSize: 12, color: tokens.accent, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 2. BONDS TAB
  // ═══════════════════════════════════════

  Widget _buildBondsTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bond Calculations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Price, Yield, Duration & Convexity for fixed-income securities', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        Wrap(spacing: 16, runSpacing: 12, children: [
          _inputField(tokens: tokens, label: 'Face Value', controller: _bondFaceCtrl, prefix: r'$'),
          _inputField(tokens: tokens, label: 'Coupon Rate %', controller: _bondCouponCtrl, suffix: '%'),
          _inputField(tokens: tokens, label: 'Yield to Maturity %', controller: _bondYieldCtrl, suffix: '%'),
          _inputField(tokens: tokens, label: 'Years to Maturity', controller: _bondYearsCtrl, suffix: 'yrs'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Frequency', style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _bondFreq,
                    dropdownColor: tokens.surface,
                    icon: Icon(Icons.arrow_drop_down, color: tokens.textSecondary, size: 18),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Annual')),
                      DropdownMenuItem(value: 2, child: Text('Semi-Annual')),
                      DropdownMenuItem(value: 4, child: Text('Quarterly')),
                      DropdownMenuItem(value: 12, child: Text('Monthly')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _bondFreq = v); },
                  ),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute Bond Metrics', _computeBond),
        _resultCard(tokens, _bondResult),
      ],
    );
  }

  // ═══════════════════════════════════════
  // 3. AMORTIZATION TAB
  // ═══════════════════════════════════════

  Widget _buildAmortizationTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loan Amortization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Monthly payment, interest breakdown, and full amortization schedule', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        Wrap(spacing: 16, runSpacing: 12, children: [
          _inputField(tokens: tokens, label: 'Loan Amount', controller: _amortLoanCtrl, prefix: r'$'),
          _inputField(tokens: tokens, label: 'Interest Rate %', controller: _amortRateCtrl, suffix: '%'),
          _inputField(tokens: tokens, label: 'Term (Years)', controller: _amortTermCtrl, suffix: 'yrs'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Frequency', style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _amortFreq,
                    dropdownColor: tokens.surface,
                    icon: Icon(Icons.arrow_drop_down, color: tokens.textSecondary, size: 18),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 12, child: Text('Monthly')),
                      DropdownMenuItem(value: 4, child: Text('Quarterly')),
                      DropdownMenuItem(value: 2, child: Text('Semi-Annual')),
                      DropdownMenuItem(value: 1, child: Text('Annual')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _amortFreq = v); },
                  ),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute Amortization', _computeAmortization),
        _resultCard(tokens, _amortResult),
        if (_showAmortSchedule && _amortSchedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Amortization Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showAmortSchedule = !_showAmortSchedule),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text(_showAmortSchedule ? 'Hide' : 'Show', style: TextStyle(fontSize: 11, color: tokens.accent)),
                      const SizedBox(width: 4),
                      Icon(_showAmortSchedule ? Icons.expand_less : Icons.expand_more, size: 14, color: tokens.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showAmortSchedule) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(tokens.background),
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 32,
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Payment', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Principal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Interest', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    ],
                    rows: _amortSchedule.take(60).map((r) {
                      return DataRow(cells: [
                        DataCell(Text('${r.period}', style: TextStyle(fontSize: 10, color: tokens.textSecondary))),
                        DataCell(Text(r.payment > 0 ? _fmtMoney(r.payment) : '—', style: TextStyle(fontSize: 10, color: tokens.textPrimary, fontFamily: 'monospace'))),
                        DataCell(Text(_fmtMoney(r.principal), style: TextStyle(fontSize: 10, color: tokens.textPrimary, fontFamily: 'monospace'))),
                        DataCell(Text(_fmtMoney(r.interest), style: TextStyle(fontSize: 10, color: const Color(0xFFEF4444), fontFamily: 'monospace'))),
                        DataCell(Text(_fmtMoney(r.balance), style: TextStyle(fontSize: 10, color: tokens.textSecondary, fontFamily: 'monospace'))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (_amortSchedule.length > 60)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Showing first 60 of ${_amortSchedule.length} payments', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ],
    );
  }

  // ═══════════════════════════════════════
  // 4. STATISTICS TAB
  // ═══════════════════════════════════════

  Widget _buildStatisticsTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Mean, Median, Standard Deviation, Variance & more', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        _inputField(tokens: tokens, label: 'Data (comma-separated)', controller: _statsInputCtrl, width: 400),
        const SizedBox(height: 6),
        Text('Enter numbers separated by commas or spaces. At least 2 numbers required.', style: TextStyle(fontSize: 10, color: tokens.textMuted, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        _computeBtn(tokens, 'Compute Statistics', _computeStats),
        _resultCard(tokens, _statsResult),
      ],
    );
  }

  // ═══════════════════════════════════════
  // 5. DEPRECIATION TAB
  // ═══════════════════════════════════════

  Widget _buildDepreciationTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Depreciation Methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Straight-Line, Double-Declining Balance & Sum-of-the-Years-Digits', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        Wrap(spacing: 16, runSpacing: 12, children: [
          _inputField(tokens: tokens, label: 'Asset Cost', controller: _depCostCtrl, prefix: r'$'),
          _inputField(tokens: tokens, label: 'Salvage Value', controller: _depSalvageCtrl, prefix: r'$'),
          _inputField(tokens: tokens, label: 'Useful Life (Years)', controller: _depLifeCtrl, suffix: 'yrs'),
        ]),
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute All Methods', _computeDepreciation),
        _resultCard(tokens, _depResult),
        if (_showDepSchedule && _depSchedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Year-by-Year Comparison', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(tokens.background),
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 32,
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Year', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Method', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Expense', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Accumulated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Book Value', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  ],
                  rows: _depSchedule.map((r) {
                    return DataRow(cells: [
                      DataCell(Text('Yr ${r.year}', style: TextStyle(fontSize: 10, color: tokens.textSecondary))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: r.method == 'SL' ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : r.method == 'DDB' ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r.method, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: r.method == 'SL' ? const Color(0xFF3B82F6) : r.method == 'DDB' ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
                      )),
                      DataCell(Text(_fmtMoney(r.expense), style: TextStyle(fontSize: 10, color: tokens.textPrimary, fontFamily: 'monospace'))),
                      DataCell(Text(_fmtMoney(r.accumulated), style: TextStyle(fontSize: 10, color: tokens.textSecondary, fontFamily: 'monospace'))),
                      DataCell(Text(_fmtMoney(r.bookValue), style: TextStyle(fontSize: 10, color: tokens.textPrimary, fontFamily: 'monospace'))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════
  // 6. BREAKEVEN TAB
  // ═══════════════════════════════════════

  Widget _buildBreakevenTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breakeven Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Fixed costs, variable costs, contribution margin & breakeven point', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        Wrap(spacing: 16, runSpacing: 12, children: [
          _inputField(tokens: tokens, label: 'Fixed Costs', controller: _beFixedCtrl, prefix: r'$'),
          _inputField(tokens: tokens, label: 'Variable Cost/Unit', controller: _beVarCtrl, prefix: r'$'),
          _inputField(tokens: tokens, label: 'Price/Unit', controller: _bePriceCtrl, prefix: r'$'),
        ]),
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute Breakeven', _computeBreakeven),
        _resultCard(tokens, _beResult),
      ],
    );
  }

  // ═══════════════════════════════════════
  // 7. DATE FUNCTIONS TAB
  // ═══════════════════════════════════════

  Widget _buildDateFunctionsTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Functions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Days between dates, day count conventions, settlement/maturity calculations', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        Wrap(spacing: 24, runSpacing: 16, children: [
          // Date 1
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date 1 (Start)', style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _pickDate(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: tokens.accent),
                      const SizedBox(width: 8),
                      Text(
                        '${_date1.year}-${_date1.month.toString().padLeft(2, '0')}-${_date1.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Date 2
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date 2 (End)', style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _pickDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: tokens.accent),
                      const SizedBox(width: 8),
                      Text(
                        '${_date2.year}-${_date2.month.toString().padLeft(2, '0')}-${_date2.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Convention
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Day Count Convention', style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dateConvention,
                    dropdownColor: tokens.surface,
                    icon: Icon(Icons.arrow_drop_down, color: tokens.textSecondary, size: 18),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: '30/360', child: Text('30/360')),
                      DropdownMenuItem(value: 'Actual/360', child: Text('Actual/360')),
                      DropdownMenuItem(value: 'Actual/365', child: Text('Actual/365')),
                      DropdownMenuItem(value: 'Actual/Actual', child: Text('Actual/Actual')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _dateConvention = v); },
                  ),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute Date Difference', _computeDateFunctions),
        _resultCard(tokens, _dateResult),
      ],
    );
  }

  // ═══════════════════════════════════════
  // 8. CURRENCY & PERCENTAGE TAB
  // ═══════════════════════════════════════

  Widget _buildCurrencyPctTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Currency & Percentage Functions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('Percentage change, markup, margin & discount calculations', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        // Sub-tabs
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: tokens.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pctSubTab(tokens, 'pct_change', '% Change'),
              const SizedBox(width: 2),
              _pctSubTab(tokens, 'markup', 'Markup'),
              const SizedBox(width: 2),
              _pctSubTab(tokens, 'margin', 'Margin'),
              const SizedBox(width: 2),
              _pctSubTab(tokens, 'discount', 'Discount'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Inputs based on sub-tab
        switch (_currPctTab) {
          'pct_change' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Old Value', controller: _pctOldCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'New Value', controller: _pctNewCtrl, prefix: r'$'),
          ]),
          'markup' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Cost Price', controller: _markupCostCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'Markup Percentage', controller: _markupPctCtrl, suffix: '%'),
          ]),
          'margin' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Cost Price', controller: _marginCostCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'Margin Percentage', controller: _marginPctCtrl, suffix: '%'),
          ]),
          'discount' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Original Price', controller: _discPriceCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'Discount Percentage', controller: _discPctCtrl, suffix: '%'),
          ]),
          _ => const SizedBox.shrink(),
        },
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute', _computeCurrencyPct),
        _resultCard(tokens, _currPctResult),
      ],
    );
  }

  Widget _pctSubTab(ThemeTokens tokens, String value, String label) {
    final active = _currPctTab == value;
    return GestureDetector(
      onTap: () => setState(() { _currPctTab = value; _currPctResult = ''; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? tokens.textPrimary : tokens.textMuted)),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 9. ADVANCED INVESTMENT TAB
  // ═══════════════════════════════════════

  Widget _buildAdvancedTab(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Advanced Investment Functions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text('CAGR, Holding Period Return, EAR & Nominal/Effective rate conversion', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const Divider(height: 24),
        // Sub-tabs
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: tokens.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _advSubTab(tokens, 'cagr', 'CAGR'),
              const SizedBox(width: 2),
              _advSubTab(tokens, 'hpr', 'HPR'),
              const SizedBox(width: 2),
              _advSubTab(tokens, 'ear', 'EAR'),
              const SizedBox(width: 2),
              _advSubTab(tokens, 'nominal_effective', 'Nom ↔ Eff'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        switch (_advTab) {
          'cagr' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Begin Value', controller: _cagrBeginCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'End Value', controller: _cagrEndCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'Years', controller: _cagrYearsCtrl, suffix: 'yrs'),
          ]),
          'hpr' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Begin Value', controller: _hprBeginCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'End Value', controller: _hprEndCtrl, prefix: r'$'),
            _inputField(tokens: tokens, label: 'Income', controller: _hprIncomeCtrl, prefix: r'$'),
          ]),
          'ear' => Wrap(spacing: 16, runSpacing: 12, children: [
            _inputField(tokens: tokens, label: 'Nominal Rate %', controller: _earNominalCtrl, suffix: '%'),
            _inputField(tokens: tokens, label: 'Compounding Periods/yr', controller: _earPeriodsCtrl),
          ]),
          'nominal_effective' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _nomEffToEffective = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _nomEffToEffective ? tokens.accent.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Nominal → Effective', style: TextStyle(fontSize: 11, fontWeight: _nomEffToEffective ? FontWeight.w600 : FontWeight.w500, color: _nomEffToEffective ? tokens.accent : tokens.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _nomEffToEffective = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_nomEffToEffective ? tokens.accent.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Effective → Nominal', style: TextStyle(fontSize: 11, fontWeight: !_nomEffToEffective ? FontWeight.w600 : FontWeight.w500, color: !_nomEffToEffective ? tokens.accent : tokens.textMuted)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 16, runSpacing: 12, children: [
                _inputField(tokens: tokens, label: _nomEffToEffective ? 'Nominal Rate %' : 'Effective Rate %', controller: _nomEffNominalCtrl, suffix: '%'),
                _inputField(tokens: tokens, label: 'Compounding Periods/yr', controller: _nomEffPeriodsCtrl),
              ]),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
        const SizedBox(height: 20),
        _computeBtn(tokens, 'Compute', _computeAdvanced),
        _resultCard(tokens, _advResult),
      ],
    );
  }

  Widget _advSubTab(ThemeTokens tokens, String value, String label) {
    final active = _advTab == value;
    return GestureDetector(
      onTap: () => setState(() { _advTab = value; _advResult = ''; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? tokens.textPrimary : tokens.textMuted)),
      ),
    );
  }
}

// ── Data classes ──

class _CashFlowItem {
  double amount;
  int frequency;
  _CashFlowItem({required this.amount, this.frequency = 1});
}

class _AmortRow {
  final int period;
  final double payment;
  final double principal;
  final double interest;
  final double balance;
  _AmortRow({required this.period, required this.payment, required this.principal, required this.interest, required this.balance});
}

class _DepRow {
  final int year;
  final double expense;
  final double accumulated;
  final double bookValue;
  final String method;
  _DepRow({required this.year, required this.expense, required this.accumulated, required this.bookValue, this.method = 'SL'});
}
