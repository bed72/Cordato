import 'dart:io';

import 'package:localstore/localstore.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpenseRepository({
  required final Localstore _database,
  required final IWidgetClient _client,
}) implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async {
    try {
      int matches = 0;
      final records = await _records();
      _order(records, null);

      final descriptions = <String>{};
      final search = query.toLowerCase();
      final suggestions = <ExpenseSuggestionEntity>[];

      for (final record in records) {
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

      return .unmodifiable(suggestions);
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> getById({required String id}) async {
    try {
      return ExpenseResponse.fromJson(await _record(id)).toEntity();
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      await _record(id);
      await _database.collection('expenses').doc(id).delete();
      _client.monthlyRefresh();
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
    final first = from == null ? null : _date(from);
    final last = to == null
        ? null
        : _date(DateTime.utc(to.year, to.month, to.day + 1));

    try {
      final records = (await _records()).where((record) {
        final date = record['occurred_on'] as String;

        return (category == null || record['category'] as String == category) &&
            (first == null || date.compareTo(first) >= 0) &&
            (last == null || date.compareTo(last) < 0);
      }).toList();

      _order(records, sort);
      final items = records.skip((page - 1) * size).take(size + 1).toList();

      return ExpensePageEntity(
        nextPage: items.length > size ? page + 1 : null,
        items: items
            .take(size)
            .map((record) => ExpenseResponse.fromJson(record).toEntity())
            .toList(),
      );
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
    if (cents != null) _validateAmount(cents);

    final fields = <String, dynamic>{
      'amount': ?cents,
      'description': ?description?.trim(),
      'category': ?category?.value,
      if (occurredOn != null) 'occurred_on': _date(occurredOn),
    };
    if (fields.isEmpty) return getById(id: id);

    try {
      final record = {...await _record(id), ...fields};
      await _database.collection('expenses').doc(id).set(record);
      _client.monthlyRefresh();

      return ExpenseResponse.fromJson(record).toEntity();
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
    _validateAmount(cents);

    try {
      final document = _database.collection('expenses').doc();
      final record = <String, dynamic>{
        'id': document.id,
        'amount': cents,
        'category': category.value,
        'description': description.trim(),
        'occurred_on': _date(occurredOn ?? DateTime.now()),
      };

      await document.set(record);
      _client.monthlyRefresh();

      return ExpenseResponse.fromJson(record).toEntity();
    } on FileSystemException {
      throw ExpenseException(errors: .unknown());
    }
  }

  Future<Map<String, dynamic>> _record(String id) async {
    final record = await _database.collection('expenses').doc(id).get();
    if (record == null) {
      throw ExpenseException(
        errors: const ErrorsEntity(
          errors: [ErrorEntity(code: 'expense_not_found')],
        ),
      );
    }

    return record;
  }

  Future<List<Map<String, dynamic>>> _records() async {
    final documents = await _database.collection('expenses').get();
    return documents?.values
            .map((document) => document as Map<String, dynamic>)
            .toList() ??
        [];
  }

  void _validateAmount(int cents) {
    if (cents <= 0) {
      throw ExpenseException(
        errors: const ErrorsEntity(
          errors: [ErrorEntity(code: 'invalid_amount', parameter: 'amount')],
        ),
      );
    }
  }

  String _date(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).toIso8601String();

  void _order(List<Map<String, dynamic>> records, String? sort) {
    final fields = (sort ?? '-occurred_on,-id').split(',');
    final ordering = <({String field, bool descending})>[];

    for (final fieldOrder in fields) {
      final descending = fieldOrder.startsWith('-');
      final field = descending ? fieldOrder.substring(1) : fieldOrder;
      if (!const {
        'id',
        'amount',
        'description',
        'category',
        'occurred_on',
      }.contains(field)) {
        throw ArgumentError.value(sort, 'sort');
      }
      ordering.add((field: field, descending: descending));
    }
    if (!ordering.any((item) => item.field == 'id')) {
      ordering.add((field: 'id', descending: false));
    }

    records.sort((first, second) {
      for (final item in ordering) {
        final comparison = switch (item.field) {
          'amount' => (first['amount'] as int).compareTo(
            second['amount'] as int,
          ),
          'description' => (first['description'] as String? ?? '').compareTo(
            second['description'] as String? ?? '',
          ),
          _ => (first[item.field] as String).compareTo(
            second[item.field] as String,
          ),
        };
        if (comparison != 0) return item.descending ? -comparison : comparison;
      }

      return 0;
    });
  }
}
