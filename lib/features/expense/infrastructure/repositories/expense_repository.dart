import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/daos/suggestions_dao.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpenseRepository({
  required final SuggestionsDao _dao,
  required final IWidgetClient _widgetClient,
  required final DatabaseClient _databaseClient,
}) implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async {
    try {
      final records = await _dao.get(query: query);

      return List<ExpenseSuggestionEntity>.unmodifiable(
        records.map(
          (record) => ExpenseSuggestionResponse.fromRecord(record).toEntity(),
        ),
      );
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }
  }

  @override
  Future<ExpenseEntity> getById({required int id}) async {
    try {
      final record = await (_databaseClient.select(
        _databaseClient.expensesTable,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (record == null) {
        throw ExpenseException(
          errors: const ErrorsEntity(
            errors: [ErrorEntity(code: 'expense_not_found')],
          ),
        );
      }

      return ExpenseResponse.fromRecord(record).toEntity();
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }
  }

  @override
  Future<void> delete({required int id}) async {
    try {
      final deleted = await (_databaseClient.delete(
        _databaseClient.expensesTable,
      )..where((row) => row.id.equals(id))).go();

      if (deleted == 0) {
        throw ExpenseException(
          errors: const ErrorsEntity(
            errors: [ErrorEntity(code: 'expense_not_found')],
          ),
        );
      }
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }

    _widgetClient.monthlyRefresh();
  }

  @override
  Future<ExpensePageEntity> get({
    int page = 1,
    int pageSize = 30,
    String? sort,
    DateTime? to,
    DateTime? from,
    String? category,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page');

    if (category != null) {
      CategoryEnum.values.firstWhere((item) => item.value == category);
    }

    final ordering = _ordering(sort);
    final size = pageSize > 0 ? pageSize : 30;
    final last = to == null ? null : _date(to);
    final first = from == null ? null : _date(from);

    try {
      final data = _databaseClient.select(_databaseClient.expensesTable);
      data.where(
        (row) => row.profileId.equalsExp(
          subqueryExpression<int>(
            _databaseClient.selectOnly(_databaseClient.profilesTable)
              ..addColumns([_databaseClient.profilesTable.id]),
          ),
        ),
      );
      if (category != null) {
        data.where((row) => row.category.equals(category));
      }
      if (first != null) {
        data.where((row) => row.occurredOn.isBiggerOrEqualValue(first));
      }
      if (last != null) {
        data.where((row) => row.occurredOn.isSmallerOrEqualValue(last));
      }

      data.limit(size + 1, offset: (page - 1) * size);
      data.orderBy([for (final term in ordering) (_) => term]);
      final records = await data.get();

      return ExpensePageEntity(
        nextPage: records.length > size ? page + 1 : null,
        items: records
            .take(size)
            .map((record) => ExpenseResponse.fromRecord(record).toEntity())
            .toList(),
      );
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }
  }

  @override
  Future<ExpenseEntity> update({
    required int id,
    int? cents,
    String? description,
    DateTime? occurredOn,
    CategoryEnum? category,
  }) async {
    if (cents != null) _amount(cents);

    if (!_hasUpdates(
      cents: cents,
      description: description,
      occurredOn: occurredOn,
      category: category,
    )) {
      return getById(id: id);
    }
    final date = occurredOn == null ? null : _date(occurredOn);

    late final ExpenseEntity updated;
    try {
      updated = await _databaseClient.transaction(() async {
        final records =
            await (_databaseClient.update(
              _databaseClient.expensesTable,
            )..where((row) => row.id.equals(id))).writeReturning(
              ExpensesTableCompanion(
                amount: cents == null ? const .absent() : Value(cents),
                description: description == null
                    ? const .absent()
                    : Value(description.trim()),
                category: category == null
                    ? const .absent()
                    : Value(category.value),
                occurredOn: date == null ? const .absent() : Value(date),
              ),
            );

        if (records.isEmpty) {
          throw ExpenseException(
            errors: const ErrorsEntity(
              errors: [ErrorEntity(code: 'expense_not_found')],
            ),
          );
        }
        return ExpenseResponse.fromRecord(records.single).toEntity();
      });
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }

    _widgetClient.monthlyRefresh();
    return updated;
  }

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    CategoryEnum category = .other,
    DateTime? occurredOn,
  }) async {
    _amount(cents);
    final date = occurredOn == null ? null : _date(occurredOn);
    final statement = date == null
        ? '''
INSERT INTO expenses (profile_id, amount, category, description)
SELECT id, ?, ?, ? FROM profiles
RETURNING *
'''
        : '''
INSERT INTO expenses (profile_id, amount, category, description, occurred_on)
SELECT id, ?, ?, ?, ? FROM profiles
RETURNING *
''';

    late final ExpenseEntity created;
    try {
      created = await _databaseClient.transaction(() async {
        final records = await _databaseClient.customWriteReturning(
          statement,
          variables: [
            .withInt(cents),
            .withString(category.value),
            .withString(description.trim()),
            if (date != null) Variable.withString(date),
          ],
          updateKind: .insert,
          updates: {_databaseClient.expensesTable},
        );
        if (records.isEmpty) {
          throw ExpenseException(
            errors: const ErrorsEntity(
              errors: [ErrorEntity(code: 'profile_not_found')],
            ),
          );
        }

        final record = _databaseClient.expensesTable.map(records.single.data);
        return ExpenseResponse.fromRecord(record).toEntity();
      });
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }

    _widgetClient.monthlyRefresh();
    return created;
  }

  bool _hasUpdates({
    int? cents,
    String? description,
    DateTime? occurredOn,
    CategoryEnum? category,
  }) =>
      cents != null ||
      description != null ||
      occurredOn != null ||
      category != null;

  void _amount(int cents) {
    if (cents <= 0) {
      throw ExpenseException(
        errors: const ErrorsEntity(
          errors: [ErrorEntity(code: 'invalid_amount', parameter: 'amount')],
        ),
      );
    }
  }

  String _date(DateTime date) {
    if (date.year < 1 || date.year > 9999) {
      throw ArgumentError.value(date, 'occurredOn');
    }
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).toIso8601String().split('T').first;
  }

  List<OrderingTerm> _ordering(String? sort) {
    bool includesId = false;
    final ordering = <OrderingTerm>[];
    final table = _databaseClient.expensesTable;

    for (final fieldOrder in (sort ?? '-occurred_on,-id').split(',')) {
      final descending = fieldOrder.startsWith('-');
      final field = descending ? fieldOrder.substring(1) : fieldOrder;
      final Expression<Object> expression = switch (field) {
        'id' => table.id,
        'amount' => table.amount,
        'category' => table.category,
        'occurred_on' => table.occurredOn,
        'description' => ifNull(table.description, const Constant('')),
        _ => throw ArgumentError.value(sort, 'sort'),
      };

      includesId = includesId || field == 'id';
      ordering.add(
        OrderingTerm(expression: expression, mode: descending ? .desc : .asc),
      );
    }

    if (!includesId) ordering.add(.asc(table.id));

    return ordering;
  }

  Never _failure(Object error, StackTrace stackTrace) {
    if (error is FileSystemException) {
      throw ExpenseException(errors: .unknown());
    }

    if (error is SqliteException &&
        const {
          SqlError.SQLITE_BUSY,
          SqlError.SQLITE_FULL,
          SqlError.SQLITE_IOERR,
          SqlError.SQLITE_LOCKED,
          SqlError.SQLITE_READONLY,
          SqlError.SQLITE_CANTOPEN,
        }.contains(error.resultCode)) {
      throw ExpenseException(errors: .unknown());
    }

    Error.throwWithStackTrace(error, stackTrace);
  }
}
