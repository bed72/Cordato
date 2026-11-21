import 'package:flutter_test/flutter_test.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/infrastructure/mappers/expense_mapper.dart';

void main() {
  group('Storage diagnostics', () {
    test('preserves native code order without native messages', () {
      final statuses = [
        ...DbResult.error(
          type: ResultType.sysIoGeneric,
          message: 'private path',
        ).statuses,
        ...DbResult.error(
          type: ResultType.bizValueLessThanMinValue,
          message: 'private amount',
        ).statuses,
      ];

      final failure = ExpenseMapper.failure(DbException(statuses));

      expect(failure.errors.errors.map((error) => error.code), [
        ResultType.sysIoGeneric.codeKey,
        ResultType.bizValueLessThanMinValue.codeKey,
      ]);
      expect(
        failure.errors.errors.every(
          (error) => error.detail == null && error.title == null,
        ),
        isTrue,
      );
    });

    test('uses safe fallback for failed acknowledgements without statuses', () {
      expect(
        () => ExpenseMapper.checkMutation(
          DbResult(statuses: [], hasErrors: true),
        ),
        throwsA(
          isA<ExpenseException>().having(
            (error) => error.errors.errors,
            'fallback errors',
            isNotEmpty,
          ),
        ),
      );
    });

    test('does not reinterpret an empty successful query as a mutation', () {
      expect(
        () => ExpenseMapper.checkQuery(
          QueryResult(type: ResultType.success, data: []),
        ),
        returnsNormally,
      );
      expect(
        () => ExpenseMapper.checkMutation(DbResult.success()),
        throwsA(
          isA<ExpenseException>().having(
            (error) => error.errors.errors.single.code,
            'not found',
            'expense_not_found',
          ),
        ),
      );
    });

    test(
      'checks query failure acknowledgements before accepting empty history',
      () {
        expect(
          () => ExpenseMapper.checkQuery(
            QueryResult(
              type: ResultType.sysIoGeneric,
              data: [],
              message: 'private',
            ),
          ),
          throwsA(isA<ExpenseException>()),
        );
      },
    );

    test(
      'propagates query developer errors instead of an expected failure',
      () {
        expect(
          () => ExpenseMapper.checkQuery(
            QueryResult(
              type: ResultType.devFieldNotFound,
              data: [],
              message: 'private',
            ),
          ),
          throwsA(isA<DbException>()),
        );
      },
    );
  });
}
