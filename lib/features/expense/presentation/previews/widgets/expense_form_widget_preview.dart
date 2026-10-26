import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

import 'package:cordato/features/expense/presentation/previews/fakes/expense_preview_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';

import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_skeleton_widget.dart';

import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_description_validation.dart';

@CordatoPreview(
  group: 'Expense / Formulário',
  name: 'Cadastro',
  size: cordatoPhonePreviewSize,
)
Widget previewExpenseFormCreation() => _formPreview();

@CordatoPreview(
  group: 'Expense / Formulário',
  name: 'Edição',
  size: cordatoPhonePreviewSize,
)
Widget previewUpdateExpenseFormWidget() => _formPreview(editing: true);

@CordatoPreview(
  group: 'Expense / Formulário',
  name: 'Carregando despesa',
  size: cordatoPhonePreviewSize,
)
Widget previewLoadingExpenseFormWidget() =>
    _formPreview(editing: true, loading: true);

Widget _formPreview({bool editing = false, bool loading = false}) {
  final expense = ExpenseEntity(
    id: 'preview-expense',
    cents: .create(cents: 1500),
    description: 'Ônibus e metrô',
    occurredOn: DateTime(2026, 10, 5),
    category: .transport,
  );
  return PreviewResourceWidget<ExpenseBloc>(
    create: () {
      final repository = ExpensePreviewRepository(expense: expense);
      final bloc = ExpenseBloc(repository: repository);
      if (editing) bloc.add(ExpenseRequestedEvent(id: expense.id));
      return bloc;
    },
    dispose: (bloc) => bloc.close(),
    builder: (bloc) => PreviewResourceWidget<ExpenseSuggestionsBloc>(
      create: () => ExpenseSuggestionsBloc(
        repository: ExpensePreviewRepository(expense: expense),
      ),
      dispose: (suggestions) => suggestions.close(),
      builder: (suggestions) => BlocBuilder<ExpenseBloc, ExpenseState>(
        bloc: bloc,
        builder: (_, _) {
          final form = ExpenseFormWidget(
            expenseBloc: bloc,
            enabled: !loading,
            suggestionsBloc: suggestions,
            dateFormatter: DateFormatter(),
            id: editing ? expense.id : null,
            moneyFormatter: MoneyFormatter(),
            initialExpense: editing ? expense : null,
            validator: const ExpenseFormValidator(
              centsValidation: ExpenseCentsValidation(),
              dateValidation: ExpenseDateValidation(),
              descriptionValidation: ExpenseDescriptionValidation(),
            ),
          );
          return Scaffold(
            appBar: const ExpenseAppBarWidget(),
            body: SafeArea(
              child: loading ? ExpenseSkeletonWidget(child: form) : form,
            ),
          );
        },
      ),
    ),
  );
}
