import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expenses_list_preview_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Setembro / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Setembro / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewMonthlyExpensesScreen() => _screenPreview();

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Alimentação / Setembro',
  size: cordatoPhonePreviewSize,
)
Widget previewCategoryExpensesScreen() => _screenPreview(category: 'food');

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Carregando setembro',
  size: cordatoPhonePreviewSize,
)
Widget previewLoadingMonthlyExpensesScreen() => _screenPreview(loading: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Mês vazio',
  size: cordatoPhonePreviewSize,
)
Widget previewEmptyMonthlyExpensesScreen() => _screenPreview(empty: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Falha mensal com retry',
  size: cordatoPhonePreviewSize,
)
Widget previewFailureMonthlyExpensesScreen() => _screenPreview(failure: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Entrada geral e agrupamentos',
  size: cordatoPhonePreviewSize,
)
Widget previewGeneralExpensesScreen() => _screenPreview(general: true);

Widget _screenPreview({
  String? category,
  bool empty = false,
  bool loading = false,
  bool failure = false,
  bool general = false,
}) {
  final repository = ExpensesListPreviewRepository(
    loading: loading,
    failure: failure ? .unknown() : null,
    items:
        empty
              ? []
              : [
                  for (int index = 0; index < 30; index++)
                    ExpenseEntity(
                      id: 'september-$index',
                      category: .food,
                      occurredOn: DateTime(2026, 9, 30 - index),
                      description: 'Gasto de setembro ${index + 1}',
                      cents: .create(cents: 1500 + index * 100).right,
                    ),
                  for (int index = 0; index < 7; index++)
                    ExpenseEntity(
                      id: 'october-$index',
                      category: .transport,
                      cents: .create(cents: 2500).right,
                      occurredOn: DateTime(2026, 10, 7 - index),
                      description: 'Gasto de outubro ${index + 1}',
                    ),
                ]
          ..sort(
            (first, second) => second.occurredOn.compareTo(first.occurredOn),
          ),
  );

  return ExpensesScreen(
    category: category,
    onBackPressed: () {},
    moneyFormatter: MoneyFormatter(),
    period: general
        ? null
        : (from: DateTime(2026, 9), to: DateTime(2026, 9, 30)),
    getCommand: GetExpensesCommand(repository: repository),
    deleteCommand: DeleteExpenseCommand(repository: repository),
    dateFormatter: DateFormatter(now: () => DateTime(2026, 10, 7)),
  );
}
