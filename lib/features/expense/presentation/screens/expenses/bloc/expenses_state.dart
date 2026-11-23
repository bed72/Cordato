import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

final class ExpensesData({
  List<ExpenseEntity> items = const [],
  final int? nextPage,
  final DateTime? to,
  final DateTime? from,
  final String? category,
  final bool hasLoaded = false,
}) {
  final List<ExpenseEntity> items = List.unmodifiable(items);
  bool get hasFilters => category != null || from != null || to != null;
}

sealed class const ExpensesState({required final ExpensesData data}) {
  bool get isLoading => this is ExpensesLoading;
  bool get isBusy =>
      isLoading || this is ExpensesDeleting || this is ExpensesReregistering;
  bool get isEmpty =>
      (this is ExpensesReady || this is ExpensesDeleted) &&
      data.hasLoaded &&
      data.items.isEmpty &&
      data.nextPage == null;
}

final class const ExpensesInitial({required super.data})
    extends ExpensesState {}

final class const ExpensesLoading({
  required super.data,
  required final bool refresh,
}) extends ExpensesState {}

final class const ExpensesReady({required super.data}) extends ExpensesState {}

final class const ExpensesFailure({
  required super.data,
  required final ErrorsEntity errors,
  required final bool refresh,
}) extends ExpensesState {}

final class const ExpensesDeleting({required super.data, required final int id})
    extends ExpensesState {}

final class const ExpensesDeleted({required super.data, required final int id})
    extends ExpensesState {}

final class const ExpensesDeleteFailure({
  required super.data,
  required final int id,
  required final ErrorsEntity errors,
}) extends ExpensesState {}

final class const ExpensesReregistering({
  required super.data,
  required final int id,
}) extends ExpensesState {}

final class const ExpensesReregistered({
  required super.data,
  required final ExpenseEntity expense,
}) extends ExpensesState {}

final class const ExpensesReregisterFailure({
  required super.data,
  required final ErrorsEntity errors,
}) extends ExpensesState {}
