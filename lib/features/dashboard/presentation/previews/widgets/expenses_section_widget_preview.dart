import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/expenses_preview_repository.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção carregando',
  size: Size(390.0, 520.0),
)
Widget previewLoadingExpensesSectionWidget() => _sectionPreview();

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção vazia',
  size: Size(390.0, 220.0),
)
Widget previewEmptyExpensesSectionWidget() => _sectionPreview(
  result: Right(ExpensePageEntity(items: [], next: null, prev: null)),
);

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção com falha',
  size: Size(390.0, 240.0),
)
Widget previewFailureExpensesSectionWidget() =>
    _sectionPreview(result: Left(ErrorsEntity.unknown()));

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção com despesas e ver tudo',
  size: Size(390.0, 520.0),
)
Widget previewExpensesSectionWidget() => _sectionPreview(
  result: Right(_expensesPage()),
  onSeeAllExpensesPressed: () {},
);

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção com despesas sem ver tudo',
  size: Size(390.0, 520.0),
)
Widget previewExpensesSectionWithoutSeeAllWidget() =>
    _sectionPreview(result: Right(_expensesPage()));

Widget _sectionPreview({
  GetRepositoryType? result,
  VoidCallback? onSeeAllExpensesPressed,
}) => PreviewResourceWidget<GetExpensesCommand>(
  create: () {
    final command = GetExpensesCommand(
      repository: ExpensesPreviewRepository(
        type:
            result ??
            Right(ExpensePageEntity(items: [], next: null, prev: null)),
      ),
    );
    if (result != null) {
      command.execute.run((pageSize: 6, pageLink: null));
    }
    return command;
  },
  dispose: (command) => command.dispose(),
  builder: (command) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: ExpensesSectionWidget(
        limit: 6,
        command: command,
        dateFormatter: DateFormatter(now: () => DateTime(2026, 10, 7)),
        moneyFormatter: MoneyFormatter(),
        onSeeAllExpensesPressed: onSeeAllExpensesPressed,
      ),
    ),
  ),
);

ExpensePageEntity _expensesPage() {
  final fixtures =
      <({String description, int cents, ExpenseCategoryEnum category})>[
        (description: 'Mercado da semana', cents: 24590, category: .food),
        (description: 'Aluguel', cents: 180000, category: .housing),
        (description: 'Combustível', cents: 15000, category: .transport),
        (description: 'Consulta médica', cents: 28000, category: .health),
        (description: 'Cinema com a família', cents: 9600, category: .leisure),
        (
          description: 'Assinatura de música',
          cents: 2190,
          category: .subscriptions,
        ),
      ];

  return ExpensePageEntity(
    next: null,
    prev: null,
    items: [
      for (final (index, fixture) in fixtures.indexed)
        ExpenseEntity(
          id: 'preview-expense-$index',
          description: fixture.description,
          cents: AmountValueObject.create(cents: fixture.cents).right,
          occurredOn: index == fixtures.length - 1
              ? DateTime(2025, 12, 31)
              : DateTime(2026, 10, 7 - index),
          category: fixture.category,
        ),
    ],
  );
}
