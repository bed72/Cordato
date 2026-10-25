import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

final class ExpensesData({
  List<ExpenseEntity> items = const [],
  final String? next,
  final String? category,
  final DateTime? from,
  final DateTime? to,
  final bool hasLoaded = false,
}) {
  final List<ExpenseEntity> items = List.unmodifiable(items);
}

sealed class const ExpensesState({required final ExpensesData data}) {
  bool get isLoading => this is ExpensesLoading;
  bool get isBusy => isLoading || this is ExpensesDeleting;
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

final class const ExpensesDeleting({
  required super.data,
  required final String id,
}) extends ExpensesState {}

final class const ExpensesDeleted({
  required super.data,
  required final String id,
}) extends ExpensesState {}

final class const ExpensesDeleteFailure({
  required super.data,
  required final String id,
  required final ErrorsEntity errors,
}) extends ExpensesState {}
