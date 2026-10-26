import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/hold_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/calculator/cents_calculator_keyboard_widget.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/authentication/presentation/widgets/amount_field_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_suggestion_item_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_description_validation.dart';

import '../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  late ExpenseRepositoryMock repository;
  late ExpenseSuggestionsBloc suggestionsBloc;
  late ExpenseBloc Function() factory;
  late List<ExpenseBloc> blocs;
  late List<ExpenseEntity> updated;
  ValueNotifier<Widget>? content;
  Widget? app;
  final expense = ExpenseEntity(
    id: '1',
    description: 'Original',
    cents: .create(cents: 1500),
    occurredOn: DateUtils.dateOnly(DateTime.now()),
    category: .food,
  );
  const validator = ExpenseFormValidator(
    centsValidation: ExpenseCentsValidation(),
    dateValidation: ExpenseDateValidation(),
    descriptionValidation: ExpenseDescriptionValidation(),
  );
  setUp(() {
    repository = ExpenseRepositoryMock();
    when(() => repository.suggestions(query: any(named: 'query')))
        .thenAnswer((_) async => []);
    blocs = [];
    updated = [];
    content = null;
    app = null;
    factory = () {
      final bloc = ExpenseBloc(repository: repository);
      blocs.add(bloc);
      return bloc;
    };
    when(() => repository.getById(id: '1')).thenAnswer((_) async => expense);
    when(() => repository.update(id: '1', description: 'Novo'))
        .thenAnswer((_) async => expense);
    when(
      () => repository.create(
        cents: 100,
        description: 'Novo',
        occurredOn: expense.occurredOn,
      ),
    ).thenAnswer((_) async => expense);
  });

  Future<void> pump(
    WidgetTester tester, {
    String? id = '1',
    bool returnToPrevious = false,
    ExpenseBloc Function()? blocFactory,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    if (content == null) {
      suggestionsBloc = ExpenseSuggestionsBloc(repository: repository);
      addTearDown(suggestionsBloc.close);
    }
    final screen = ExpenseScreen(
      id: id,
      returnToPrevious: returnToPrevious,
      expenseBloc: blocFactory ?? factory,
      suggestionsBloc: suggestionsBloc,
      validator: validator,
      dateFormatter: DateFormatter(),
      moneyFormatter: MoneyFormatter(),
    );
    final firstPump = content == null;
    if (firstPump) {
      final notifier = ValueNotifier<Widget>(screen);
      content = notifier;
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context
              ..route(
                '/previous',
                child: (_, _) => const Scaffold(body: Text('Anterior')),
              )
              ..route(
                '/dashboard',
                child: (_, _) => const Scaffold(body: Text('Dashboard')),
              )
              ..route(
                '/expense',
                child: (_, _) => ValueListenableBuilder<Widget>(
                  valueListenable: notifier,
                  builder: (_, child, _) => child,
                ),
              );
          },
        ),
      );
      final router = modularRouterConfig(
        boot.routes,
        injector: boot.injector,
        manager: boot.manager,
        initialRoute: '/previous',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        (router.routerDelegate as ChangeNotifier).dispose();
        (router.routeInformationProvider as PlatformRouteInformationProvider)
            .dispose();
        boot.injector.dispose();
        notifier.dispose();
      });
      app = MaterialApp.router(
        theme: Themes.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (_, child) => ToastProviderWidget(child: child!),
      );
    } else {
      content!.value = screen;
    }
    await tester.pumpWidget(app!);
    if (firstPump) {
      await tester.pumpAndSettle();
      unawaited(
        tester
            .element(find.text('Anterior'))
            .pushNamed<ExpenseEntity>('/expense')
            .then((value) {
              if (value != null) updated.add(value);
            }),
      );
    }
    await tester.pump();
    if (firstPump) {
      await tester.pump(const Duration(milliseconds: 400));
    }
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

  Finder updateButton() => find.widgetWithText(ElevatedButton, 'Atualizar');
  Future<void> edit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '  Novo  ');
    await tester.pump();
    await tester.tap(updateButton());
    await tester.pump();
  }

  Future<void> prepareCreation(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '  Novo  ');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.tap(find.text('✓'));
    await tester.pumpAndSettle();
  }

  Future<void> suggest(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump();
    await tester.pump(ExpenseSuggestionsBloc.debounce);
    await tester.pumpAndSettle();
  }

  final rentSuggestion = ExpenseSuggestionEntity(
    id: 'rent',
    description: 'Aluguel',
    cents: 160000,
  );
  final marketSuggestion = ExpenseSuggestionEntity(
    id: 'market',
    description: 'Mercado',
  );

  testWidgets('description has no clear button when populated', (tester) async {
    await pump(tester, id: null);
    await tester.enterText(find.byType(TextField).first, 'Mercado');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .decoration!
          .suffixIcon,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Mercado',
    );
    await finish(tester);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('calculator respects bottom safe area on ${platform.name}', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await pump(tester, id: null);
      await tester.tap(find.byType(AmountFieldWidget));
      await tester.pumpAndSettle();

      final keyboard = find.byType(CentsCalculatorKeyboardWidget);
      expect(keyboard, findsOneWidget);
      expect(
        tester.getBottomLeft(keyboard).dy,
        lessThanOrEqualTo(844 - 48 - 32),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('1'));
      await tester.tap(find.text('✓'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
        100,
      );
      await finish(tester);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'selection fills description and cents, editing removes automatic amount',
    (tester) async {
      when(() => repository.suggestions(query: 'Alu'))
          .thenAnswer((_) async => [rentSuggestion]);
      await pump(tester, id: null);
      await suggest(tester, ' Alu ');
      expect(
        tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
        0,
      );
      expect(find.byType(ExpenseSuggestionItemWidget), findsOneWidget);
      await tester.tap(find.byType(ExpenseSuggestionItemWidget));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseSuggestionItemWidget), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Aluguel',
      );
      expect(
        tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
        160000,
      );
      verifyNever(
        () => repository.create(
          cents: any(named: 'cents'),
          description: any(named: 'description'),
          occurredOn: any(named: 'occurredOn'),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Outro');
      await tester.pumpAndSettle();
      expect(
        tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
        0,
      );
      await finish(tester);
    },
  );

  testWidgets('manual amount survives suggestion until explicit replacement', (
    tester,
  ) async {
    when(() => repository.suggestions(query: 'Alu'))
        .thenAnswer((_) async => [rentSuggestion]);
    await pump(tester, id: null);
    await prepareCreation(tester);
    expect(
      tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
      100,
    );
    await suggest(tester, 'Alu');
    expect(find.text('Usar descrição'), findsOneWidget);
    await tester.tap(find.byType(ExpenseSuggestionItemWidget));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
      100,
    );
    await tester.tap(find.textContaining('Usar valor sugerido:'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
      160000,
    );
    await finish(tester);
  });

  testWidgets('description-only selection opens calculator once', (
    tester,
  ) async {
    when(() => repository.suggestions(query: 'Mer'))
        .thenAnswer((_) async => [marketSuggestion]);
    await pump(tester, id: null);
    await suggest(tester, 'Mer');
    await tester.tap(find.byType(ExpenseSuggestionItemWidget));
    await tester.pumpAndSettle();
    expect(find.text('Valor do gasto'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Mercado',
    );
    await tester.tap(find.text('1'));
    await tester.tap(find.text('✓'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
      100,
    );
    await finish(tester);
  });

  testWidgets('failure is silent and manual form remains usable', (
    tester,
  ) async {
    when(() => repository.suggestions(query: 'Novo'))
        .thenThrow(ExpenseException(errors: .unknown()));
    await pump(tester, id: null);
    await prepareCreation(tester);
    expect(
      tester.widget<AmountFieldWidget>(find.byType(AmountFieldWidget)).value,
      100,
    );
    expect(find.byType(ExpenseSuggestionItemWidget), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'unchanged edit is disabled, trim belongs to form and success is unique',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(updateButton()).onPressed, isNull);
      await edit(tester);
      await tester.pumpAndSettle();
      expect(updated, [expense]);
      expect(find.text('Gasto atualizado'), findsOneWidget);
      await pump(tester);
      expect(updated, hasLength(1));
      expect(blocs, hasLength(1));
      verify(() => repository.getById(id: '1')).called(1);
      verify(() => repository.update(id: '1', description: 'Novo')).called(1);
      verifyNever(() => repository.suggestions(query: any(named: 'query')));
      await finish(tester);
    },
  );

  testWidgets(
    '422 field errors preserve input, remaining errors show once and editing clears only field',
    (tester) async {
      when(() => repository.update(id: '1', description: 'Novo')).thenThrow(
        ExpenseException(
          errors: const ErrorsEntity(
            errors: [
              ErrorEntity(
                status: '422',
                pointer: '/data/attributes/description',
                detail: 'Descrição inválida',
              ),
              ErrorEntity(status: '500', detail: 'Tente mais tarde'),
            ],
          ),
        ),
      );
      await pump(tester);
      await tester.pumpAndSettle();
      await edit(tester);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFieldWidget>(find.byType(TextFieldWidget).first)
            .failure,
        'Descrição inválida',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '  Novo  ',
      );
      expect(find.text('Tente mais tarde'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Novo');
      await tester.pump();
      expect(
        tester
            .widget<TextFieldWidget>(find.byType(TextFieldWidget).first)
            .failure,
        isNull,
      );
      when(() => repository.update(id: '1', description: 'Novo'))
          .thenAnswer((_) async => expense);
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(updated, [expense]);
      await finish(tester);
    },
  );

  testWidgets(
    'pending update disables fields and factory replacement closes previous owner',
    (tester) async {
      final pending = Completer<ExpenseEntity>();
      when(() => repository.update(id: '1', description: 'Novo'))
          .thenAnswer((_) => pending.future);
      await pump(tester);
      await tester.pumpAndSettle();
      await edit(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      final old = blocs.single;
      ExpenseBloc replacement() {
        final bloc = ExpenseBloc(repository: repository);
        blocs.add(bloc);
        return bloc;
      }

      await pump(tester, blocFactory: replacement);
      expect(old.isClosed, isTrue);
      pending.complete(expense);
      await tester.pumpAndSettle();
      expect(updated, isEmpty);
      expect(find.text('Gasto atualizado'), findsNothing);
      await finish(tester);
    },
  );

  testWidgets('load error retries manually and rebuild does not repeat load', (
    tester,
  ) async {
    when(() => repository.getById(id: '1'))
        .thenThrow(ExpenseException(errors: .unknown()));
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar a despesa.'), findsOneWidget);
    await pump(tester);
    verify(() => repository.getById(id: '1')).called(1);
    when(() => repository.getById(id: '1')).thenAnswer((_) async => expense);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'creation validates before network and keyboard opens calculator',
    (tester) async {
      await pump(tester, id: null);
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      verifyZeroInteractions(repository);
      await prepareCreation(tester);
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Gasto cadastrado'), findsOneWidget);
      verify(
        () => repository.create(
          cents: 100,
          description: 'Novo',
          occurredOn: expense.occurredOn,
        ),
      ).called(1);
      await finish(tester);
    },
  );

  testWidgets(
    'hold success resets only after completion and permits another creation',
    (tester) async {
      await pump(tester, id: null);
      await prepareCreation(tester);
      final button = tester.widget<HoldButtonWidget>(
        find.byType(HoldButtonWidget),
      );
      button.onHoldComplete!();
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      await prepareCreation(tester);
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      verify(
        () => repository.create(
          cents: 100,
          description: 'Novo',
          occurredOn: expense.occurredOn,
        ),
      ).called(2);
      await finish(tester);
    },
  );

  testWidgets(
    'creation requested by the previous route pops instead of resetting to Dashboard',
    (tester) async {
      await pump(tester, id: null, returnToPrevious: true);
      await prepareCreation(tester);
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.text('Anterior'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.byType(ExpenseScreen), findsNothing);
      expect(updated, [expense]);
      await finish(tester);
    },
  );

  for (final systemBack in [false, true]) {
    for (final nextAttempt in ['none', 'failure', 'pending']) {
      testWidgets(
        'hold result survives $nextAttempt and ${systemBack ? 'system' : 'app bar'} back',
        (tester) async {
          await pump(tester, id: null, returnToPrevious: true);
          await prepareCreation(tester);
          tester
              .widget<HoldButtonWidget>(find.byType(HoldButtonWidget))
              .onHoldComplete!();
          await tester.pumpAndSettle();
          final pending = Completer<ExpenseEntity>();
          if (nextAttempt != 'none') {
            final operation = when(
              () => repository.create(
                cents: 100,
                description: 'Novo',
                occurredOn: expense.occurredOn,
              ),
            );
            if (nextAttempt == 'failure') {
              operation.thenThrow(ExpenseException(errors: .unknown()));
            } else {
              operation.thenAnswer((_) => pending.future);
            }
            await prepareCreation(tester);
            tester
                .widget<HoldButtonWidget>(find.byType(HoldButtonWidget))
                .onTap!();
            await tester.pump();
            if (nextAttempt == 'failure') await tester.pumpAndSettle();
          }
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            ToastProviderWidget.of(tester.element(find.byType(ExpenseScreen)))
                .hide();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.byType(BackButtonWidget));
          }
          if (nextAttempt == 'pending') pending.complete(expense);
          await tester.pumpAndSettle();
          expect(find.text('Anterior'), findsOneWidget);
          expect(updated, [expense]);
          expect(find.byType(ExpenseScreen), findsNothing);
          await finish(tester);
        },
      );
    }
  }

  testWidgets('leaving creation without a confirmed save returns no result', (
    tester,
  ) async {
    await pump(tester, id: null, returnToPrevious: true);
    await tester.tap(find.byType(BackButtonWidget));
    await tester.pumpAndSettle();
    expect(find.text('Anterior'), findsOneWidget);
    expect(updated, isEmpty);
    verifyZeroInteractions(repository);
    await finish(tester);
  });

  for (final loadFailure in [false, true]) {
    testWidgets(
      'back navigates directly from ${loadFailure ? 'load error' : 'form'} without mutating',
      (tester) async {
        if (loadFailure) {
          when(() => repository.getById(id: '1'))
              .thenThrow(ExpenseException(errors: .unknown()));
        }
        await pump(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButtonWidget));
        await tester.pumpAndSettle();
        expect(find.text('Anterior'), findsOneWidget);
        expect(find.byType(ExpenseScreen), findsNothing);
        expect(updated, isEmpty);
        verifyNever(() => repository.update(id: '1', description: 'Novo'));
        await finish(tester);
      },
    );
  }

  testWidgets(
    'leaving during a pending load suppresses late effects and closes bloc',
    (tester) async {
      final pending = Completer<ExpenseEntity>();
      when(() => repository.getById(id: '1')).thenAnswer((_) => pending.future);
      await pump(tester);
      expect(find.bySemanticsLabel('Carregando despesa'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.completeError(ExpenseException(errors: .unknown()));
      await tester.pumpAndSettle();
      await finish(tester);
    },
  );
}
