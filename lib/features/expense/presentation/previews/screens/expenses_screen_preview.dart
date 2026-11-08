import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/previews/fakes/expenses_list_preview_repository.dart';

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
  name: 'Categoria sem mês',
  size: cordatoPhonePreviewSize,
)
Widget previewCategoryHistoryExpensesScreen() =>
    _screenPreview(category: 'food', general: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Categoria e mês / Carregando',
  size: cordatoPhonePreviewSize,
)
Widget previewLoadingFilteredExpensesScreen() =>
    _screenPreview(category: 'food', loading: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Categoria e mês / Erro',
  size: cordatoPhonePreviewSize,
)
Widget previewFailureFilteredExpensesScreen() =>
    _screenPreview(category: 'food', failure: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Categoria e mês / Vazio',
  size: cordatoPhonePreviewSize,
)
Widget previewEmptyFilteredExpensesScreen() =>
    _screenPreview(category: 'food', empty: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Categoria longa / Estreito / Claro',
  size: Size(320.0, 844.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Categoria longa / Estreito / Escuro',
  size: Size(320.0, 844.0),
  brightness: Brightness.dark,
)
Widget previewNarrowFiltersExpensesScreen() =>
    _screenPreview(category: 'gifts_and_donations');

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Filtros / Texto ampliado / Claro',
  size: Size(320.0, 844.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Filtros / Texto ampliado / Escuro',
  size: Size(320.0, 844.0),
  brightness: Brightness.dark,
)
Widget previewLargeTextFiltersExpensesScreen() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: _screenPreview(category: 'gifts_and_donations'),
  ),
);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Categoria futura',
  size: cordatoPhonePreviewSize,
)
Widget previewFutureCategoryExpensesScreen() =>
    _screenPreview(category: 'future_category');

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Intervalo não mensal',
  size: cordatoPhonePreviewSize,
)
Widget previewCustomPeriodExpensesScreen() => _screenPreview(
  category: 'food',
  period: (from: DateTime(2026, 9, 10), to: DateTime(2026, 9, 20)),
);

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

@CordatoPreview(
  group: 'Expense / Recadastro',
  name: 'Long press / Sucesso',
  size: cordatoPhonePreviewSize,
)
Widget previewReregistrationSuccess() => _screenPreview(
  general: true,
  creationDelay: const Duration(seconds: 2),
);

@CordatoPreview(
  group: 'Expense / Recadastro',
  name: 'Long press / Falha',
  size: cordatoPhonePreviewSize,
)
Widget previewReregistrationFailure() => _screenPreview(
  general: true,
  creationFails: true,
  creationDelay: const Duration(seconds: 2),
);

@CordatoPreview(
  group: 'Expense / Recadastro',
  name: 'Long press / Loading prolongado',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewReregistrationLoading() => _screenPreview(
  general: true,
  creationDelay: const Duration(seconds: 10),
);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Sem despesas / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Sem despesas / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewEmptyGeneralExpensesScreen() =>
    _screenPreview(general: true, empty: true);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Filtros sem resultados / Texto ampliado',
  size: Size(320.0, 568.0),
)
Widget previewLargeTextEmptyExpensesScreen() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: _screenPreview(category: 'food', empty: true),
  ),
);

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Cabeçalho recolhível / Tela baixa',
  size: Size(390.0, 420.0),
  brightness: Brightness.dark,
)
Widget previewScrollableHeaderExpensesScreen() => _screenPreview();

@CordatoPreview(
  group: 'Expense / Listagem',
  name: 'Cabeçalho recolhível / Movimento reduzido',
  size: cordatoPhonePreviewSize,
)
Widget previewReducedMotionExpensesScreen() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: _screenPreview(general: true),
  ),
);

Widget _screenPreview({
  String? category,
  ({DateTime from, DateTime to})? period,
  bool empty = false,
  bool loading = false,
  bool failure = false,
  bool general = false,
  bool creationFails = false,
  Duration creationDelay = Duration.zero,
}) {
  final repository = ExpensesListPreviewRepository(
    loading: loading,
    failure: failure ? .unknown() : null,
    creationFailure: creationFails ? .unknown() : null,
    creationDelay: creationDelay,
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
                      cents: .create(cents: 1500 + index * 100),
                    ),
                  for (int index = 0; index < 7; index++)
                    ExpenseEntity(
                      id: 'october-$index',
                      category: .transport,
                      cents: .create(cents: 2500),
                      occurredOn: DateTime(2026, 10, 7 - index),
                      description: 'Gasto de outubro ${index + 1}',
                    ),
                  ExpenseEntity(
                    id: 'september-donation',
                    category: .giftsAndDonations,
                    cents: .create(cents: 5000),
                    occurredOn: DateTime(2026, 9, 15),
                    description: 'Doação de setembro',
                  ),
                  ExpenseEntity(
                    id: 'august-food',
                    category: .food,
                    cents: .create(cents: 3000),
                    occurredOn: DateTime(2026, 8, 31),
                    description: 'Alimentação de agosto',
                  ),
                ]
          ..sort(
            (first, second) => second.occurredOn.compareTo(first.occurredOn),
          ),
  );

  return PreviewResourceWidget<ExpensesBloc Function()>(
    create: () =>
        () => ExpensesBloc(repository: repository),
    dispose: (_) {},
    builder: (factory) => ExpensesScreen(
      category: category,
      moneyFormatter: MoneyFormatter(),
      period: general
          ? null
          : period ?? (from: DateTime(2026, 9), to: DateTime(2026, 9, 30)),
      bloc: factory,
      dateFormatter: DateFormatter(now: () => DateTime(2026, 10, 7)),
    ),
  );
}
