import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expense_preview_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/update_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_skeleton_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';
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
    cents: .create(cents: 1500).right,
    description: 'Ônibus e metrô',
    occurredOn: DateTime(2026, 10, 5),
    category: .transport,
  );
  return PreviewResourceWidget<
    ({CreateExpenseCommand create, UpdateExpenseCommand update})
  >(
    create: () {
      final repository = ExpensePreviewRepository(expense: expense);
      return (
        create: CreateExpenseCommand(repository: repository),
        update: UpdateExpenseCommand(repository: repository),
      );
    },
    dispose: (commands) {
      commands.create.dispose();
      commands.update.dispose();
    },
    builder: (commands) {
      final form = ExpenseFormWidget(
        id: editing ? expense.id : null,
        initialExpense: editing ? expense : null,
        enabled: !loading,
        createCommand: commands.create,
        updateCommand: commands.update,
        moneyFormatter: MoneyFormatter(),
        dateFormatter: DateFormatter(),
        validator: const ExpenseFormValidator(
          centsValidation: ExpenseCentsValidation(),
          dateValidation: ExpenseDateValidation(),
          descriptionValidation: ExpenseDescriptionValidation(),
        ),
        onExpenseCreated: (_) {},
        onExpenseUpdated: (_, _) {},
      );
      return Scaffold(
        appBar: ExpenseAppBarWidget(onBackPressed: () {}),
        body: SafeArea(
          child: loading ? ExpenseSkeletonWidget(child: form) : form,
        ),
      );
    },
  );
}
