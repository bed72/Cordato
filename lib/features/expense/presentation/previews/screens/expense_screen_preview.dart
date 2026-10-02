import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expense_preview_repository.dart';

import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_value_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';

@CordatoPreview(
  group: 'Gastos / Telas',
  name: 'Novo gasto',
  size: cordatoPhonePreviewSize,
)
Widget previewExpenseScreen() => PreviewResourceWidget<CreateExpenseCommand>(
  create: () =>
      CreateExpenseCommand(repository: const ExpensePreviewRepository()),
  dispose: (command) => command.dispose(),
  builder: (command) => ExpenseScreen(
    command: command,
    formatter: MoneyFormatter(),
    validator: const ExpenseFormValidator(
      valueValidation: ExpenseValueValidation(),
      dateValidation: ExpenseDateValidation(),
      descriptionValidation: ExpenseDescriptionValidation(),
    ),
    onBackPressed: () {},
    onExpenseCreated: (_) {},
  ),
);
