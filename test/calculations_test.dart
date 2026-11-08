import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Extracted calculator formulas from the UI widgets to verify correctness.
/// These are pure mathematical functions — no Flutter dependencies needed.

// ── SIP Formula ──
// FV = P × [((1+r)^n - 1) / r] × (1+r)
// where P=monthly, r=monthly rate, n=total months
double sipFutureValue(double monthlyInvestment, double annualRatePercent, int years) {
  final monthlyRate = (annualRatePercent / 100) / 12;
  final totalMonths = years * 12;
  if (monthlyRate > 0) {
    return monthlyInvestment *
        ((pow(1 + monthlyRate, totalMonths) - 1) / monthlyRate) *
        (1 + monthlyRate);
  }
  return monthlyInvestment * totalMonths;
}

double sipInflationAdjustedValue(
    double monthlyInvestment, double annualRatePercent, int years, double inflationRatePercent) {
  final fv = sipFutureValue(monthlyInvestment, annualRatePercent, years);
  final discountFactor = pow(1 + (inflationRatePercent / 100), -years);
  return fv * discountFactor;
}

// ── EMI Formula ──
// EMI = P × r × (1+r)^n / ((1+r)^n - 1)
double emiCalculate(double principal, double annualRatePercent, int months) {
  final r = (annualRatePercent / 100) / 12;
  if (r > 0) {
    return (principal * r * pow(1 + r, months)) / (pow(1 + r, months) - 1);
  }
  return principal / months;
}

// ── Compound Interest with monthly contributions ──
// FV = PV(1+r)^n + PMT × [((1+r)^n - 1) / r]
(double totalInvested, double totalValue, double totalInterest)
    compoundInterest(double principal, double monthlyContribution,
        double annualRatePercent, int years, int compoundFrequency) {
  final r = annualRatePercent / 100;
  final n = compoundFrequency;
  final monthlyRate = pow(1 + r / n, n / 12) - 1;
  final totalMonths = years * 12;

  final principalFV = principal * pow(1 + monthlyRate, totalMonths);
  double contributionsFV = 0;
  if (monthlyRate > 0) {
    contributionsFV = monthlyContribution *
        ((pow(1 + monthlyRate, totalMonths) - 1) / monthlyRate);
  } else {
    contributionsFV = monthlyContribution * totalMonths;
  }

  final totalValue = principalFV + contributionsFV;
  final totalInvested = principal + (monthlyContribution * totalMonths);
  final totalInterest = max(0.0, totalValue - totalInvested);
  return (totalInvested, totalValue, totalInterest);
}

// ── Inflation Impact ──
// Future Value = Amount / (1 + rate)^years
(double futureValue, double loss, double lossPercent) inflationImpact(
    double amount, double inflationRatePercent, int years) {
  double factor = 1;
  for (int i = 0; i < years; i++) {
    factor *= (1 + inflationRatePercent / 100);
  }
  final futureValue = amount / factor;
  final lossAmount = amount - futureValue;
  final lossPct = amount > 0 ? (lossAmount / amount) * 100 : 0.0;
  return (futureValue, lossAmount, lossPct);
}

// ── Indian Currency Formatting ──
String formatIndian(double value, [String symbol = '₹']) {
  final valStr = value.round().toString();
  if (valStr.length <= 3) return '$symbol$valStr';
  final lastThree = valStr.substring(valStr.length - 3);
  var remaining = valStr.substring(0, valStr.length - 3);
  final chunks = <String>[];
  while (remaining.length > 2) {
    chunks.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  if (remaining.isNotEmpty) chunks.insert(0, remaining);
  return '$symbol${chunks.join(',')},$lastThree';
}

// ── US Currency Formatting ──
String formatUS(double value, [String symbol = r'$']) {
  final valStr = value.round().toString();
  final result = StringBuffer();
  int count = 0;
  for (int i = valStr.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) result.write(',');
    result.write(valStr[i]);
    count++;
  }
  return '$symbol${result.toString().split('').reversed.join()}';
}

void main() {
  // ════════════════════════════════════════════════════════════════
  // SIP Calculator Tests
  // ════════════════════════════════════════════════════════════════

  group('SIP Calculator', () {
    test('₹5000/month at 12% for 10 years', () {
      final fv = sipFutureValue(5000, 12.0, 10);
      // Expected: ~₹11,61,695.38
      expect(fv, closeTo(1161695.38, 1.0));
    });

    test('₹10000/month at 10% for 5 years', () {
      final fv = sipFutureValue(10000, 10.0, 5);
      // Expected: ~₹7,80,823.99
      expect(fv, closeTo(780823.99, 1.0));
    });

    test('0% return equals total invested', () {
      final fv = sipFutureValue(5000, 0.0, 10);
      expect(fv, 5000 * 10 * 12); // 600,000
    });

    test('1 year SIP', () {
      final fv = sipFutureValue(5000, 12.0, 1);
      expect(fv, greaterThan(5000 * 12));
      expect(fv, closeTo(64046.64, 1.0));
    });

    test('estimated returns are positive', () {
      final fv = sipFutureValue(10000, 12.0, 20);
      final totalInvested = 10000 * 20 * 12;
      expect(fv - totalInvested, greaterThan(0));
    });

    test('higher rate yields more', () {
      final fv10 = sipFutureValue(5000, 10.0, 10);
      final fv12 = sipFutureValue(5000, 12.0, 10);
      final fv15 = sipFutureValue(5000, 15.0, 10);
      expect(fv12, greaterThan(fv10));
      expect(fv15, greaterThan(fv12));
    });

    test('longer duration yields more', () {
      final fv5 = sipFutureValue(5000, 12.0, 5);
      final fv10 = sipFutureValue(5000, 12.0, 10);
      final fv20 = sipFutureValue(5000, 12.0, 20);
      expect(fv10, greaterThan(fv5));
      expect(fv20, greaterThan(fv10));
    });

    test('inflation-adjusted today\'s value: ₹5000/month at 12% for 10 years with 6% inflation', () {
      final fv = sipFutureValue(5000, 12.0, 10);
      final adj = sipInflationAdjustedValue(5000, 12.0, 10, 6.0);
      
      // Expected FV: ~1,161,695.38
      // Expected Discount Factor: (1 + 0.06)^-10 ≈ 0.5583948
      // Expected Adjusted: 1,161,695.38 * 0.5583948 ≈ 648,684.58
      expect(adj, closeTo(648684.58, 1.0));
      expect(adj, lessThan(fv));
    });

    test('inflation-adjusted today\'s value: 0% inflation is equal to nominal future value', () {
      final fv = sipFutureValue(5000, 12.0, 10);
      final adj = sipInflationAdjustedValue(5000, 12.0, 10, 0.0);
      expect(adj, fv);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // EMI Calculator Tests
  // ════════════════════════════════════════════════════════════════

  group('EMI Calculator', () {
    test('₹10L loan at 8.5% for 10 years', () {
      final emi = emiCalculate(1000000, 8.5, 120);
      // Expected: ~₹12,398.70
      expect(emi, closeTo(12398.70, 1.0));
    });

    test('0% interest equals principal / months', () {
      final emi = emiCalculate(1200000, 0.0, 120);
      expect(emi, 10000); // 1200000 / 120
    });

    test('total payable = EMI × months', () {
      final emi = emiCalculate(500000, 10.0, 60);
      final totalPayable = emi * 60;
      expect(totalPayable, greaterThan(500000)); // More than principal
    });

    test('total interest is positive', () {
      final emi = emiCalculate(1000000, 8.5, 120);
      final totalInterest = (emi * 120) - 1000000;
      expect(totalInterest, greaterThan(0));
    });

    test('shorter tenure has higher EMI', () {
      final emi5y = emiCalculate(1000000, 8.5, 60);
      final emi10y = emiCalculate(1000000, 8.5, 120);
      expect(emi5y, greaterThan(emi10y));
    });

    test('higher rate has higher EMI', () {
      final emi8 = emiCalculate(1000000, 8.0, 120);
      final emi12 = emiCalculate(1000000, 12.0, 120);
      expect(emi12, greaterThan(emi8));
    });

    test('₹50L loan at 9% for 20 years', () {
      final emi = emiCalculate(5000000, 9.0, 240);
      // Expected: ~₹44,986
      expect(emi, closeTo(44986, 1.0));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Compound Interest Calculator Tests
  // ════════════════════════════════════════════════════════════════

  group('Compound Interest Calculator', () {
    test('₹1L initial + ₹5K/month at 10% for 10 years, monthly compounding', () {
      final (invested, value, interest) = compoundInterest(100000, 5000, 10.0, 10, 12);
      expect(invested, 100000 + 5000 * 120); // 700000
      expect(value, greaterThan(invested));
      expect(interest, greaterThan(0));
      // Total value should be around ₹12.9L
      expect(value, closeTo(1294929, 5000));
    });

    test('₹0 contributions, only principal growth', () {
      final (invested, value, interest) = compoundInterest(100000, 0, 10.0, 5, 12);
      expect(invested, 100000);
      // 1L at 10% for 5 years ≈ 164531
      expect(value, closeTo(164531, 100));
      expect(interest, closeTo(64531, 100));
    });

    test('0% rate means no interest', () {
      final (invested, value, interest) = compoundInterest(100000, 5000, 0.0, 5, 12);
      expect(invested, value);
      expect(interest, 0);
    });

    test('quarterly compounding yields less than monthly', () {
      final (_, monthlyVal, _) = compoundInterest(100000, 5000, 10.0, 10, 12);
      final (_, quarterlyVal, _) = compoundInterest(100000, 5000, 10.0, 10, 4);
      expect(monthlyVal, greaterThan(quarterlyVal));
    });

    test('annual compounding yields less than quarterly', () {
      final (_, quarterlyVal, _) = compoundInterest(100000, 5000, 10.0, 10, 4);
      final (_, annualVal, _) = compoundInterest(100000, 5000, 10.0, 10, 1);
      expect(quarterlyVal, greaterThan(annualVal));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Inflation Calculator Tests
  // ════════════════════════════════════════════════════════════════

  group('Inflation Calculator', () {
    test(r'$10000 at 6% inflation for 10 years', () {
      final (fv, loss, pct) = inflationImpact(10000, 6.0, 10);
      // 10000 / 1.06^10 ≈ 5583.95
      expect(fv, closeTo(5583.95, 1.0));
      expect(loss, closeTo(4416.05, 1.0));
      expect(pct, closeTo(44.16, 0.5));
    });

    test('0% inflation preserves value', () {
      final (fv, loss, pct) = inflationImpact(10000, 0.0, 10);
      expect(fv, 10000);
      expect(loss, 0);
      expect(pct, 0);
    });

    test('100% loss after enough years at high inflation', () {
      final (fv, loss, pct) = inflationImpact(10000, 30.0, 50);
      expect(pct, greaterThan(99));
      expect(fv, lessThan(100));
    });

    test('loss increases with years', () {
      final (_, _, pct5) = inflationImpact(10000, 6.0, 5);
      final (_, _, pct10) = inflationImpact(10000, 6.0, 10);
      final (_, _, pct20) = inflationImpact(10000, 6.0, 20);
      expect(pct10, greaterThan(pct5));
      expect(pct20, greaterThan(pct10));
    });

    test('higher inflation rate erodes more', () {
      final (_, _, pct2) = inflationImpact(10000, 2.0, 10);
      final (_, _, pct6) = inflationImpact(10000, 6.0, 10);
      final (_, _, pct15) = inflationImpact(10000, 15.0, 10);
      expect(pct6, greaterThan(pct2));
      expect(pct15, greaterThan(pct6));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Indian Currency Formatting Tests
  // ════════════════════════════════════════════════════════════════

  group('Indian Currency Formatting', () {
    test('small amounts', () {
      expect(formatIndian(0), '₹0');
      expect(formatIndian(500), '₹500');
      expect(formatIndian(999), '₹999');
    });

    test('thousands (Indian grouping)', () {
      expect(formatIndian(1000), '₹1,000');
      expect(formatIndian(10000), '₹10,000');
      expect(formatIndian(99999), '₹99,999');
    });

    test('lakhs', () {
      expect(formatIndian(100000), '₹1,00,000');
      expect(formatIndian(1500000), '₹15,00,000');
    });

    test('crores', () {
      expect(formatIndian(10000000), '₹1,00,00,000');
      expect(formatIndian(125000000), '₹12,50,00,000');
    });

    test('custom symbol', () {
      expect(formatIndian(100000, '\u20B9'), '\u20B91,00,000');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // US Currency Formatting Tests
  // ════════════════════════════════════════════════════════════════

  group('US Currency Formatting', () {
    test('small amounts', () {
      expect(formatUS(0), r'$0');
      expect(formatUS(500), r'$500');
      expect(formatUS(999), r'$999');
    });

    test('thousands (US grouping)', () {
      expect(formatUS(1000), r'$1,000');
      expect(formatUS(10000), r'$10,000');
      expect(formatUS(999999), r'$999,999');
    });

    test('millions', () {
      expect(formatUS(1000000), r'$1,000,000');
      expect(formatUS(15000000), r'$15,000,000');
    });

    test('billions', () {
      expect(formatUS(1000000000), r'$1,000,000,000');
    });
  });
}
