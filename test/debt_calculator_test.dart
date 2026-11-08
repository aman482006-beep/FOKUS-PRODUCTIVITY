import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════
// Extracted debt calculator logic for unit testing
// (mirrors DebtCalculatorPage._simulate and related methods)
// ════════════════════════════════════════════════════════════════

class YearlyProjection {
  final int year;
  final double remainingBalance;
  final double interestPaidThisYear;
  final double principalPaidThisYear;

  YearlyProjection({
    required this.year,
    required this.remainingBalance,
    required this.interestPaidThisYear,
    required this.principalPaidThisYear,
  });
}

class SimulationResult {
  final int totalMonths;
  final double totalInterest;
  final double totalPaid;
  final List<YearlyProjection> yearlyProjections;
  final List<double> monthlyBalances;

  SimulationResult({
    required this.totalMonths,
    required this.totalInterest,
    required this.totalPaid,
    required this.yearlyProjections,
    required this.monthlyBalances,
  });
}

double calculateEmiForTerm(double principal, double annualRate, int years) {
  final r = (annualRate / 100) / 12;
  final n = years * 12;
  if (r == 0) return principal / n;
  return principal * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
}

SimulationResult simulate({
  required double principal,
  required double annualRate,
  required double baseMonthlyPayment,
  double stepUpPercent = 0.0,
  double extraMonthly = 0.0,
  double lumpSumVal = 0.0,
  int lumpSumMo = 0,
  bool accelerated = false,
}) {
  final r = (annualRate / 100) / 12;
  double balance = principal;
  double totalInterest = 0;
  double totalPaid = 0;
  int monthsCount = 0;

  final yearlyProjections = <YearlyProjection>[];
  final monthlyBalances = <double>[principal];

  double interestThisYear = 0;
  double principalPaidThisYear = 0;
  double currentMonthlyBase = baseMonthlyPayment;

  while (balance > 0.01 && monthsCount < 600) {
    monthsCount++;

    if (accelerated && monthsCount > 1 && (monthsCount - 1) % 12 == 0) {
      currentMonthlyBase = currentMonthlyBase * (1 + stepUpPercent / 100);
    }

    final interest = balance * r;

    double payment = currentMonthlyBase;
    if (accelerated) {
      payment += extraMonthly;
      if (monthsCount == lumpSumMo) {
        payment += lumpSumVal;
      }
    }

    if (payment <= interest && r > 0) {
      return SimulationResult(
        totalMonths: -1,
        totalInterest: double.infinity,
        totalPaid: double.infinity,
        yearlyProjections: [],
        monthlyBalances: [],
      );
    }

    final actualPayment = min(payment, balance + interest);
    final principalPaid = actualPayment - interest;

    balance -= principalPaid;
    totalInterest += interest;
    totalPaid += actualPayment;

    interestThisYear += interest;
    principalPaidThisYear += principalPaid;
    monthlyBalances.add(max(0.0, balance));

    if (monthsCount % 12 == 0 || balance <= 0.01) {
      yearlyProjections.add(YearlyProjection(
        year: (monthsCount / 12).ceil(),
        remainingBalance: max(0.0, balance),
        interestPaidThisYear: interestThisYear,
        principalPaidThisYear: principalPaidThisYear,
      ));
      interestThisYear = 0;
      principalPaidThisYear = 0;
    }
  }

  return SimulationResult(
    totalMonths: monthsCount,
    totalInterest: totalInterest,
    totalPaid: totalPaid,
    yearlyProjections: yearlyProjections,
    monthlyBalances: monthlyBalances,
  );
}

String formatMonthsToYearsAndMonths(int totalMonths) {
  if (totalMonths == -1) return 'Infinite Debt';
  final years = totalMonths ~/ 12;
  final months = totalMonths % 12;
  if (years == 0) return '$months month${months == 1 ? '' : 's'}';
  if (months == 0) return '$years year${years == 1 ? '' : 's'}';
  return '$years yr${years == 1 ? '' : 's'} $months mo${months == 1 ? '' : 's'}';
}

// ════════════════════════════════════════════════════════════════
// Debt Calculator Tests
// ════════════════════════════════════════════════════════════════

void main() {
  group('EMI calculation for term', () {
    test('10L at 9.5% for 15 years', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 15);
      expect(emi, closeTo(10442, 1.0));
    });

    test('5L at 8% for 10 years', () {
      final emi = calculateEmiForTerm(500000, 8.0, 10);
      expect(emi, closeTo(6066, 1.0));
    });

    test('0% interest equals simple division', () {
      final emi = calculateEmiForTerm(1200000, 0.0, 10);
      expect(emi, 10000); // 1200000 / 120
    });

    test('higher rate gives higher EMI', () {
      final emi8 = calculateEmiForTerm(1000000, 8.0, 15);
      final emi12 = calculateEmiForTerm(1000000, 12.0, 15);
      expect(emi12, greaterThan(emi8));
    });

    test('longer term gives lower EMI', () {
      final emi10 = calculateEmiForTerm(1000000, 9.5, 10);
      final emi20 = calculateEmiForTerm(1000000, 9.5, 20);
      expect(emi20, lessThan(emi10));
    });
  });

  group('Baseline simulation', () {
    test('₹10L at 9.5% over 15 years (standard payoff)', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 15);
      final result = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      // Should take ~180 months (15 years)
      expect(result.totalMonths, closeTo(180, 2));
      expect(result.totalInterest, greaterThan(0));
      expect(result.totalPaid, greaterThan(1000000));
      // Total paid = principal + interest
      expect(result.totalPaid, closeTo(1000000 + result.totalInterest, 1));
    });

    test('monthly balances decrease over time', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 15);
      final result = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      // First balance is principal, last should be ~0
      expect(result.monthlyBalances.first, 1000000);
      expect(result.monthlyBalances.last, lessThan(1));
    });

    test('yearly projections exist', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 5);
      final result = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      expect(result.yearlyProjections.isNotEmpty, true);
      expect(result.yearlyProjections.first.year, 1);
    });

    test('final balance is zero', () {
      final emi = calculateEmiForTerm(500000, 8.0, 5);
      final result = simulate(
        principal: 500000,
        annualRate: 8.0,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      expect(result.yearlyProjections.last.remainingBalance, closeTo(0, 1));
    });
  });

  group('Accelerated simulation', () {
    test('accelerated pays off faster than baseline', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 15);
      final baseline = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      final accelerated = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        stepUpPercent: 8.0,
        extraMonthly: 2000,
        lumpSumVal: 50000,
        lumpSumMo: 12,
        accelerated: true,
      );
      expect(accelerated.totalMonths, lessThan(baseline.totalMonths));
      expect(accelerated.totalInterest, lessThan(baseline.totalInterest));
    });

    test('extra monthly payment reduces total interest', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 15);
      final baseline = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      final withExtra = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        extraMonthly: 5000,
        accelerated: true,
      );
      expect(withExtra.totalInterest, lessThan(baseline.totalInterest));
    });

    test('step-up increases payment each year', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 10);
      final noStepUp = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      final withStepUp = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        stepUpPercent: 10.0,
        accelerated: true,
      );
      expect(withStepUp.totalMonths, lessThan(noStepUp.totalMonths));
    });

    test('zero accelerators matches baseline', () {
      final emi = calculateEmiForTerm(1000000, 9.5, 15);
      final baseline = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        accelerated: false,
      );
      final same = simulate(
        principal: 1000000,
        annualRate: 9.5,
        baseMonthlyPayment: emi,
        stepUpPercent: 0.0,
        extraMonthly: 0.0,
        lumpSumVal: 0.0,
        accelerated: true,
      );
      expect(same.totalMonths, baseline.totalMonths);
      expect(same.totalInterest, closeTo(baseline.totalInterest, 0.1));
    });
  });

  group('Infinite debt detection', () {
    test('payment below interest returns infinite debt', () {
      final result = simulate(
        principal: 1000000,
        annualRate: 24.0,
        baseMonthlyPayment: 10000, // Much less than monthly interest ~20000
        accelerated: false,
      );
      expect(result.totalMonths, -1);
      expect(result.totalInterest, double.infinity);
    });

    test('very low payment triggers infinite debt', () {
      // Monthly interest on 10L at 12% = 10000. Payment of 5000 is below.
      final result = simulate(
        principal: 1000000,
        annualRate: 12.0,
        baseMonthlyPayment: 5000,
        accelerated: false,
      );
      expect(result.totalMonths, -1);
    });
  });

  group('formatMonthsToYearsAndMonths', () {
    test('infinite debt', () {
      expect(formatMonthsToYearsAndMonths(-1), 'Infinite Debt');
    });

    test('months only', () {
      expect(formatMonthsToYearsAndMonths(3), '3 months');
      expect(formatMonthsToYearsAndMonths(1), '1 month');
    });

    test('years only', () {
      expect(formatMonthsToYearsAndMonths(12), '1 year');
      expect(formatMonthsToYearsAndMonths(24), '2 years');
    });

    test('years and months', () {
      expect(formatMonthsToYearsAndMonths(15), '1 yr 3 mos');
      expect(formatMonthsToYearsAndMonths(36), '3 years');
    });

    test('zero months edge case', () {
      expect(formatMonthsToYearsAndMonths(0), '0 months');
    });
  });
}
