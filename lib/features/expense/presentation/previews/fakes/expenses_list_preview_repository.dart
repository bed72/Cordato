import 'dart:async';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class ExpensesListPreviewRepository({
  required final List<ExpenseEntity> items,
  final bool loading = false,
  final ErrorsEntity? failure,
}) implements IExpenseRepository {
  @override
  Future<GetRepositoryType> get({
    int pageSize = 30,
    DateTime? to,
    DateTime? from,
    String? category,
    String? pageLink,
  }) async {
    if (loading) return Completer<GetRepositoryType>().future;
    if (failure != null) return Left(failure!);

    final filtered = items.where((expense) {
      final day = _civilDay(expense.occurredOn);

      return (from == null || !day.isBefore(_civilDay(from))) &&
          (category == null || expense.category.value == category) &&
          (to == null || !day.isAfter(_civilDay(to)));
    }).toList();

    final offset = pageLink == null
        ? 0
        : int.parse(Uri.parse(pageLink).queryParameters['offset']!);
    final page = filtered.skip(offset).take(pageSize).toList();
    final end = offset + page.length;

    return Right(
      ExpensePageEntity(
        prev: null,
        items: page,
        next: end < filtered.length ? '?offset=$end' : null,
      ),
    );
  }

  DateTime _civilDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<GetByIdRepositoryType> getById({required String id}) async {
    final expense = items.where((expense) => expense.id == id).firstOrNull;
    return expense == null ? Left(ErrorsEntity.unknown()) : Right(expense);
  }

  @override
  Future<DeleteRepositoryType> delete({required String id}) async =>
      const Right(false);

  @override
  Future<CreateRepositoryType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) async => Left(ErrorsEntity.unknown());

  @override
  Future<UpdateRepositoryType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async => Left(ErrorsEntity.unknown());
}
