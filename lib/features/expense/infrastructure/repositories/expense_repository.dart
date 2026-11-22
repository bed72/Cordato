import 'dart:io';

import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/application/clients/interface_widget_client.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/infrastructure/mappers/expense_mapper.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpenseRepository({
  required final ToStore _database,
  required final IWidgetClient _client,
}) implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async {
    try {
      int offset = 0;
      int matches = 0;

      final descriptions = <String>{};
      final search = query.toLowerCase();
      final suggestions = <ExpenseSuggestionEntity>[];

      while (matches < 30) {
        final history = await _database
            .query('expenses')
            .orderByDesc('occurred_on')
            .orderByDesc('id')
            .offset(offset)
            .limit(100)
            .future;

        ExpenseMapper.checkQuery(history);

        for (final record in history.data) {
          final description = record['description'] as String?;
          if (description == null ||
              description.isEmpty ||
              !description.toLowerCase().contains(search)) {
            continue;
          }

          final suggestion = ExpenseSuggestionResponse.fromJson(record);
          matches++;
          if (descriptions.add(description.toLowerCase())) {
            suggestions.add(suggestion.toEntity());
          }
          if (matches == 30) break;
        }

        if (history.data.length < 100) break;

        offset += history.data.length;
      }

      return List.unmodifiable(suggestions);
    } on DbException catch (exception) {
      throw ExpenseMapper.failure(exception);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> getById({required String id}) async {
    try {
      final records = await _database
          .query('expenses')
          .where('id', '=', id)
          .limit(1)
          .future;
      ExpenseMapper.checkQuery(records);

      if (records.data.isEmpty) throw ExpenseMapper.notFound();

      return ExpenseResponse.fromJson(records.data.single).toEntity();
    } on DbException catch (exception) {
      throw ExpenseMapper.failure(exception);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      final deleted = await _database.delete('expenses').where('id', '=', id);
      ExpenseMapper.checkMutation(deleted);
      _client.requestMonthlyRefresh();
    } on DbException catch (exception) {
      throw ExpenseMapper.failure(exception);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
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
      ExpenseCategoryEnum.values.firstWhere((item) => item.value == category);
    }

    final size = pageSize > 0 ? pageSize : 30;
    try {
      final query = _database.query('expenses');
      if (category != null) query.where('category', '=', category);

      if (from != null) query.where('occurred_on', '>=', _date(from));

      if (to != null) {
        query.where(
          'occurred_on',
          '<',
          _date(DateTime.utc(to.year, to.month, to.day + 1)),
        );
      }
      _order(query, sort);

      final records = await query
          .offset((page - 1) * size)
          .limit(size + 1)
          .future;
      ExpenseMapper.checkQuery(records);

      return ExpensePageEntity(
        nextPage: records.data.length > size ? page + 1 : null,
        items: records.data
            .take(size)
            .map((record) => ExpenseResponse.fromJson(record).toEntity())
            .toList(),
      );
    } on DbException catch (exception) {
      throw ExpenseMapper.failure(exception);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
    ExpenseCategoryEnum? category,
  }) async {
    final fields = <String, dynamic>{
      'amount': ?cents,
      'description': ?description,
      'category': ?category?.value,
      if (occurredOn != null) 'occurred_on': _date(occurredOn),
    };
    if (fields.isEmpty) return getById(id: id);

    try {
      final updated = await _database
          .update('expenses', fields)
          .where('id', '=', id);
      ExpenseMapper.checkMutation(updated);
      _client.requestMonthlyRefresh();

      return await getById(id: id);
    } on DbException catch (exception) {
      throw ExpenseMapper.failure(exception);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    ExpenseCategoryEnum category = .other,
    DateTime? occurredOn,
  }) async {
    try {
      final created = await _database.insert('expenses', {
        'amount': cents,
        'category': category.value,
        'description': description,
        'occurred_on': _date(occurredOn ?? DateTime.now()),
      });
      ExpenseMapper.checkMutation(created);
      final id = created.firstPrimaryKey;

      if (id == null) throw StateError('Missing generated expense ID');

      _client.requestMonthlyRefresh();

      return await getById(id: id);
    } on DbException catch (exception) {
      throw ExpenseMapper.failure(exception);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  String _date(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).toIso8601String();

  void _order(QueryBuilder query, String? sort) {
    bool hasId = false;
    final fields = (sort ?? '-occurred_on,-id').split(',');

    for (final ordering in fields) {
      final descending = ordering.startsWith('-');
      final field = descending ? ordering.substring(1) : ordering;
      if (!const {
        'id',
        'amount',
        'description',
        'category',
        'occurred_on',
      }.contains(field)) {
        throw ArgumentError.value(sort, 'sort');
      }

      hasId = hasId || field == 'id';
      (descending) ? query.orderByDesc(field) : query.orderByAsc(field);
    }

    if (!hasId) query.orderByAsc('id');
  }
}
