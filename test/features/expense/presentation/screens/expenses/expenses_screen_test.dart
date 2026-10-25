import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/expenses_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_dismissible_widget.dart';

import '../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  late ExpenseRepositoryMock repository;
  late ExpensesBloc Function() factory;
  late List<ExpensesBloc> blocs;
  late int changed;
  final expense = ExpenseEntity(
    id: '1',
    description: 'Mercado',
    cents: .create(cents: 1500),
    occurredOn: DateTime(2026, 9, 3),
    category: .food,
  );
  ExpensePageEntity page(List<ExpenseEntity> items) =>
      ExpensePageEntity(items: items, next: null, prev: null);
  setUp(() {
    repository = ExpenseRepositoryMock();
    blocs = [];
    changed = 0;
    factory = () {
      final bloc = ExpensesBloc(repository: repository);
      blocs.add(bloc);
      return bloc;
    };
    when(() => repository.get(pageSize: 20))
        .thenAnswer((_) async => page([expense]));
    when(() => repository.get(pageSize: 20, category: 'food'))
        .thenAnswer((_) async => page([expense]));
    when(() => repository.delete(id: '1')).thenAnswer((_) async {});
  });
  Future<void> pump(
    WidgetTester tester, {
    String? category,
    ExpensesBloc Function()? blocFactory,
    Future<ExpenseEntity?> Function(String)? onEdit,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: Themes.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ToastProviderWidget(
          child: ExpensesScreen(
            bloc: blocFactory ?? factory,
            category: category,
            dateFormatter: DateFormatter(),
            moneyFormatter: MoneyFormatter(),
            onBackPressed: () {},
            onExpensesChanged: () => changed++,
            onExpensePressed: onEdit,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    for (final bloc in blocs) {
      expect(bloc.isClosed, isTrue);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(tester.takeException(), isNull);
  }

  Future<void> requestDelete(WidgetTester tester) async {
    tester
        .widget<ExpenseDismissibleWidget>(find.byType(ExpenseDismissibleWidget))
        .onAccessibleDelete!();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'loads once across rebuild and factory replacement closes old owner',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Mercado'), findsOneWidget);
      await pump(tester);
      expect(blocs, hasLength(1));
      verify(() => repository.get(pageSize: 20)).called(1);
      final old = blocs.single;
      ExpensesBloc replacement() {
        final bloc = ExpensesBloc(repository: repository);
        blocs.add(bloc);
        return bloc;
      }

      await pump(tester, blocFactory: replacement);
      await tester.pumpAndSettle();
      expect(old.isClosed, isTrue);
      expect(blocs, hasLength(2));
      await finish(tester);
    },
  );

  testWidgets(
    'cancel does not delete and confirmed deletion waits for repository',
    (tester) async {
      final pending = Completer<void>();
      when(() => repository.delete(id: '1')).thenAnswer((_) => pending.future);
      await pump(tester);
      await tester.pumpAndSettle();
      await requestDelete(tester);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.delete(id: '1'));
      await requestDelete(tester);
      await tester.tap(find.text('Excluir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Mercado'), findsOneWidget);
      expect(changed, 0);
      expect(
        tester
            .widget<ExpenseDismissibleWidget>(
              find.byType(ExpenseDismissibleWidget),
            )
            .isDeleting,
        isTrue,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mercado'), findsNothing);
      expect(find.text('Despesa excluída'), findsOneWidget);
      expect(changed, 1);
      await pump(tester);
      expect(changed, 1);
      await finish(tester);
    },
  );

  testWidgets('delete failure keeps item and permits manual retry', (
    tester,
  ) async {
    when(() => repository.delete(id: '1'))
        .thenThrow(ExpenseException(errors: .unknown()));
    await pump(tester);
    await tester.pumpAndSettle();
    await requestDelete(tester);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsOneWidget);
    expect(changed, 0);
    when(() => repository.delete(id: '1')).thenAnswer((_) async {});
    await requestDelete(tester);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(changed, 1);
    verify(() => repository.delete(id: '1')).called(2);
    await finish(tester);
  });

  testWidgets('load failure retries and empty list is success', (tester) async {
    when(() => repository.get(pageSize: 20))
        .thenThrow(ExpenseException(errors: .unknown()));
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as despesas.'), findsOneWidget);
    when(() => repository.get(pageSize: 20)).thenAnswer((_) async => page([]));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ainda sem despesas'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('filter change invalidates pending load and stale confirmation', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await requestDelete(tester);
    await pump(tester, category: 'food');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.delete(id: '1'));
    expect(blocs.single.state.data.category, 'food');
    await finish(tester);
  });

  testWidgets(
    'edit return updates or removes item according to active filters',
    (tester) async {
      final edited = ExpenseEntity(
        id: '1',
        description: 'Transporte',
        cents: expense.cents,
        occurredOn: expense.occurredOn,
        category: .transport,
      );
      await pump(tester, category: 'food', onEdit: (_) async => edited);
      await tester.pumpAndSettle();
      tester
          .widget<ExpenseDismissibleWidget>(
            find.byType(ExpenseDismissibleWidget),
          )
          .onEdit!();
      await tester.pumpAndSettle();
      expect(find.text('Mercado'), findsNothing);
      expect(changed, 1);
      await finish(tester);
    },
  );

  testWidgets(
    'dispose during pending delete prevents late toast and callback',
    (tester) async {
      final pending = Completer<void>();
      when(() => repository.delete(id: '1')).thenAnswer((_) => pending.future);
      await pump(tester);
      await tester.pumpAndSettle();
      await requestDelete(tester);
      await tester.tap(find.text('Excluir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pumpAndSettle();
      expect(changed, 0);
      await finish(tester);
    },
  );
}
