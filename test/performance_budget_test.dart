import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/services/performance_budget.dart';

void main() {
  test('known budgets evaluate pass and fail states', () {
    final PerformanceBudgetResult? passed = evaluatePerformanceBudget(
      'search_first_page',
      const Duration(milliseconds: 1200),
    );
    final PerformanceBudgetResult? failed = evaluatePerformanceBudget(
      'search_first_page',
      const Duration(milliseconds: 3000),
    );

    expect(passed, isNotNull);
    expect(passed!.passed, isTrue);
    expect(failed, isNotNull);
    expect(failed!.passed, isFalse);
    expect(failed.overByMs, 500);
  });

  test('unknown budgets return null', () {
    expect(
      evaluatePerformanceBudget('unknown', const Duration(milliseconds: 1)),
      isNull,
    );
  });
}
