import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';

void main() {
  group('Empty expense listing', () {
    test('successful empty page enables the empty presentation', () {
      final state = ExpensesReady(data: ExpensesData(hasLoaded: true));

      expect(state.isEmpty, isTrue);
      expect(state.data.hasFilters, isFalse);
    });

    test('unloaded data is not a confirmed empty list', () {
      final state = ExpensesReady(data: ExpensesData());

      expect(state.isEmpty, isFalse);
    });

    test('pending pagination is not a confirmed empty result', () {
      final state = ExpensesDeleted(
        id: 1,
        data: ExpensesData(hasLoaded: true, nextPage: 2),
      );

      expect(state.isEmpty, isFalse);
    });

    test('initial state does not show the empty presentation', () {
      final state = ExpensesInitial(data: ExpensesData());

      expect(state.isEmpty, isFalse);
    });

    test('loading does not show stale empty feedback', () {
      final state = ExpensesLoading(
        data: ExpensesData(hasLoaded: true),
        refresh: true,
      );

      expect(state.isEmpty, isFalse);
    });

    test('request failure is not shown as an empty result', () {
      final state = ExpensesFailure(
        data: ExpensesData(hasLoaded: true),
        errors: .unknown(),
        refresh: true,
      );

      expect(state.isEmpty, isFalse);
    });

    test('deletion in progress is not confirmed empty', () {
      final state = ExpensesDeleting(
        data: ExpensesData(hasLoaded: true),
        id: 1,
      );

      expect(state.isEmpty, isFalse);
    });
  });

  group('Active filters', () {
    for (final entry in <String, ExpensesData>{
      'category': ExpensesData(category: 'food'),
      'start date': ExpensesData(from: DateTime(2026, 11)),
      'end date': ExpensesData(to: DateTime(2026, 11, 30)),
    }.entries) {
      test('${entry.key} selects filtered empty feedback', () {
        expect(entry.value.hasFilters, isTrue);
      });
    }
  });
}
