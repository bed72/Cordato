import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/budget/presentation/screens/budget_screen.dart';
import 'package:cordato/features/budget/presentation/commands/create_budget_command.dart';
import 'package:cordato/features/budget/presentation/previews/fakes/budget_preview_repository.dart';

import 'package:cordato/features/budget/presentation/validators/budget_form_validator.dart';
import 'package:cordato/features/budget/presentation/validators/budget_value_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_date_range_validation.dart';
import 'package:cordato/features/budget/presentation/validators/budget_description_validation.dart';

@CordatoPreview(
  name: 'Novo orçamento',
  group: 'Orçamentos / Telas',
  size: cordatoPhonePreviewSize,
)
Widget previewBudgetScreen() => PreviewResourceWidget<CreateBudgetCommand>(
  create: () =>
      CreateBudgetCommand(repository: const BudgetPreviewRepository()),
  dispose: (command) => command.dispose(),
  builder: (command) => BudgetScreen(
    command: command,
    formatter: MoneyFormatter(),
    validator: const BudgetFormValidator(
      valueValidation: BudgetValueValidation(),
      dateRangeValidation: BudgetDateRangeValidation(),
      descriptionValidation: BudgetDescriptionValidation(),
    ),
    onBackPressed: () {},
    onBudgetCreated: (_) {},
  ),
);
