import 'dart:async';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpensesListPreviewRepository({
  required List<ExpenseEntity> items,
  final bool loading = false,
  final ErrorsEntity? failure,
  final ErrorsEntity? creationFailure,
  final Duration creationDelay = .zero,
}) implements IExpenseRepository {
  final List<ExpenseEntity> items;

  this : items = List.of(items);

  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async => [];

  @override
  Future<ExpensePageEntity> get({
    String? sort,
    DateTime? to,
    DateTime? from,
    String? category,
    int page = 1,
    int pageSize = 30,
  }) async {
    if (loading) return Completer<ExpensePageEntity>().future;
    if (failure != null) throw ExpenseException(errors: failure!);

    final filtered = items.where((expense) {
      final day = _civilDay(expense.occurredOn);

      return (from == null || !day.isBefore(_civilDay(from))) &&
          (category == null || expense.category.value == category) &&
          (to == null || !day.isAfter(_civilDay(to)));
    }).toList();

    filtered.sort((left, right) {
      final byDay = _civilDay(left.occurredOn)
          .compareTo(_civilDay(right.occurredOn));

      return sort == 'occurred_on' ? byDay : -byDay;
    });

    final offset = (page - 1) * pageSize;
    final pageItems = filtered.skip(offset).take(pageSize).toList();
    final end = offset + pageItems.length;

    return ExpensePageEntity(
      items: pageItems,
      nextPage: end < filtered.length ? page + 1 : null,
    );
  }

  @override
  Future<ExpenseEntity> getById({required int id}) async {
    final expense = items.where((expense) => expense.id == id).firstOrNull;
    if (expense == null) throw ExpenseException(errors: .unknown());
    return expense;
  }

  @override
  Future<void> delete({required int id}) async =>
      throw ExpenseException(errors: .unknown());

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    CategoryEnum category = .other,
    DateTime? occurredOn,
  }) async {
    if (creationDelay != Duration.zero) {
      await Future<void>.delayed(creationDelay);
    }

    if (creationFailure != null) {
      throw ExpenseException(errors: creationFailure!);
    }

    final createdExpense = ExpenseEntity(
      id:
          items.fold<int>(
            0,
            (highest, item) => item.id > highest ? item.id : highest,
          ) +
          1,
      description: description,
      cents: .create(cents: cents),
      category: category,
      occurredOn: occurredOn ?? DateTime.now(),
    );
    items.add(createdExpense);

    return createdExpense;
  }

  @override
  Future<ExpenseEntity> update({
    required int id,
    CategoryEnum? category,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => throw ExpenseException(errors: .unknown());

  DateTime _civilDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
