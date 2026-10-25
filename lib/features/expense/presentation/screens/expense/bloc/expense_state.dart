import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

sealed class ExpenseState {
  const ExpenseState();

  ExpenseEntity? get expense => null;
  bool get isSubmitting => this is ExpenseSubmitting;
  bool get canSubmit =>
      this is ExpenseInitial ||
      this is ExpenseReady ||
      this is ExpenseSubmissionFailure ||
      (this is ExpenseSuccess && (this as ExpenseSuccess).keepFormOpen);
}

final class const ExpenseInitial() extends ExpenseState {}

final class const ExpenseLoading() extends ExpenseState {}

final class const ExpenseReady({@override required final ExpenseEntity expense})
    extends ExpenseState {}

final class const ExpenseLoadFailure({required final ErrorsEntity errors})
    extends ExpenseState {}

final class const ExpenseSubmitting({@override final ExpenseEntity? expense})
    extends ExpenseState {}

final class const ExpenseSubmissionFailure({
  required final ErrorsEntity errors,
  @override final ExpenseEntity? expense,
}) extends ExpenseState {}

final class const ExpenseSuccess({
  @override required final ExpenseEntity expense,
  required final bool isEditing,
  required final bool keepFormOpen,
}) extends ExpenseState {}
