import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_section_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção carregando',
  size: Size(390.0, 520.0),
)
Widget previewLoadingExpensesSectionWidget() => _sectionPreview();

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção vazia',
  size: Size(390.0, 420.0),
)
Widget previewEmptyExpensesSectionWidget() =>
    _sectionPreview(data: ExpensePageEntity(items: [], nextPage: null));

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Seção com despesas e ver tudo',
  size: Size(390.0, 520.0),
)
Widget previewExpensesSectionWidget() => _sectionPreview(data: _expensesPage());

Widget _sectionPreview({ExpensePageEntity? data}) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 24.0),
    child: ExpensesSectionWidget(
      limit: 6,
      page: data,
      moneyFormatter: MoneyFormatter(),
      dateFormatter: DateFormatter(now: () => DateTime(2026, 10, 7)),
    ),
  ),
);

ExpensePageEntity _expensesPage() {
  final fixtures = <({String description, int cents, CategoryEnum category})>[
    (description: 'Aluguel', cents: 180000, category: .housing),
    (description: 'Combustível', cents: 15000, category: .transport),
    (description: 'Consulta médica', cents: 28000, category: .health),
    (description: 'Mercado da semana', cents: 24590, category: .food),
    (description: 'Cinema com a família', cents: 9600, category: .leisure),
    (
      description: 'Assinatura de música',
      cents: 2190,
      category: .subscriptions,
    ),
  ];

  return ExpensePageEntity(
    nextPage: null,
    items: [
      for (final (index, fixture) in fixtures.indexed)
        ExpenseEntity(
          id: index + 1,
          category: fixture.category,
          description: fixture.description,
          occurredOn: DateTime(2026, 10, 7 - index),
          cents: AmountValueObject.create(cents: fixture.cents),
        ),
    ],
  );
}
