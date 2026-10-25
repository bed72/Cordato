import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/edit_user_screen.dart';

import '../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  const user = UserEntity(
    id: '1',
    name: 'Nome da API',
    email: 'person@example.com',
    status: 'active',
  );
  late UserRepositoryMock repository;
  late List<EditBloc> blocs;
  late EditBloc Function() factory;
  late List<UserEntity> updated;
  late List<Completer<UserEntity>> pendingRequests;
  late bool prepared;

  EditBloc createBloc() {
    final bloc = EditBloc(repository: repository);
    blocs.add(bloc);
    return bloc;
  }

  setUp(() {
    repository = UserRepositoryMock();
    blocs = [];
    factory = createBloc;
    updated = [];
    pendingRequests = [];
    prepared = false;
    when(() => repository.update(name: any(named: 'name')))
        .thenAnswer((_) async => user);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    EditBloc Function()? blocFactory,
    double textScale = 1,
  }) async {
    if (!prepared) {
      prepared = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final pending in pendingRequests) {
          if (!pending.isCompleted) pending.complete(user);
        }
        await tester.pumpAndSettle();
        for (final bloc in blocs) {
          expect(bloc.isClosed, isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: Themes.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: ToastProviderWidget(
            child: EditUserScreen(
              initialName: 'Pessoa',
              bloc: blocFactory ?? factory,
              onBackPressed: (_) {},
              onUpdated: (_, value) => updated.add(value),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder button() => find.widgetWithText(ElevatedButton, 'Atualizar');
  String text(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;
  String? fieldFailure(WidgetTester tester) =>
      tester.widget<TextFieldWidget>(find.byType(TextFieldWidget)).failure;
  Completer<UserEntity> hold() {
    final pending = Completer<UserEntity>();
    pendingRequests.add(pending);
    when(() => repository.update(name: any(named: 'name')))
        .thenAnswer((_) => pending.future);
    return pending;
  }

  Future<void> submit(
    WidgetTester tester, {
    String name = '  Novo nome  ',
  }) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
    await tester.tap(button());
    await tester.pump();
  }

  testWidgets(
    'blank and unchanged names do not submit, including keyboard submission',
    (tester) async {
      await pumpScreen(tester);
      expect(text(tester), 'Pessoa');
      for (final value in ['Pessoa', '  Pessoa  ', '', '   ']) {
        await tester.enterText(find.byType(TextField), value);
        expect(tester.widget<ElevatedButton>(button()).onPressed, isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      verifyZeroInteractions(repository);
    },
  );

  for (final keyboard in [false, true]) {
    testWidgets(
      '${keyboard ? 'keyboard' : 'button'} trims the form name and returns the API profile exactly once',
      (tester) async {
        await pumpScreen(tester);
        await tester.enterText(find.byType(TextField), '  Novo nome  ');
        await tester.pump();
        if (keyboard) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.tap(button());
        }
        await tester.pumpAndSettle();
        expect(updated, [same(user)]);
        expect(find.text('Nome atualizado'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        final notifier = ToastProviderWidget.of(
          tester.element(find.byType(EditUserScreen)),
        );
        final feedback = notifier.toast!.id;
        await pumpScreen(tester);
        expect(notifier.toast!.id, feedback);
        expect(updated, hasLength(1));
        expect(blocs, hasLength(1));
        verify(() => repository.update(name: 'Novo nome')).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  testWidgets(
    'pending submission disables the field and button and blocks duplicates',
    (tester) async {
      final pending = hold();
      await pumpScreen(tester);
      await submit(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      tester.widget<TextField>(find.byType(TextField)).onSubmitted!(
        'Outro nome',
      );
      await tester.pump();
      verify(() => repository.update(name: 'Novo nome')).called(1);
      expect(updated, isEmpty);
      pending.complete(user);
      await tester.pumpAndSettle();
      expect(updated, [same(user)]);
      verifyNoMoreInteractions(repository);
    },
  );

  testWidgets(
    '422 name errors stay in the field, remaining errors appear in a single toast',
    (tester) async {
      when(() => repository.update(name: any(named: 'name'))).thenAnswer(
        (_) async => throw UserException(
          errors: const ErrorsEntity(
            errors: [
              ErrorEntity(
                status: '422',
                pointer: '/data/attributes/name',
                detail: 'Nome recusado',
              ),
              ErrorEntity(
                status: '422',
                pointer: '/data/attributes/name',
                title: 'Outra regra',
              ),
              ErrorEntity(
                status: '503',
                title: 'Falha adicional',
                detail: 'Tente mais tarde.',
              ),
            ],
          ),
        ),
      );
      await pumpScreen(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(fieldFailure(tester), 'Nome recusado\nOutra regra');
      expect(find.text('Tente mais tarde.'), findsOneWidget);
      expect(text(tester), '  Novo nome  ');
      expect(updated, isEmpty);
      final notifier = ToastProviderWidget.of(
        tester.element(find.byType(EditUserScreen)),
      );
      final feedback = notifier.toast!.id;
      await pumpScreen(tester);
      expect(notifier.toast!.id, feedback);
      await tester.enterText(find.byType(TextField), 'Outro nome');
      await tester.pump();
      expect(fieldFailure(tester), isNull);
      expect(notifier.toast!.id, feedback);
      await tester.pump(const Duration(seconds: 7));
      verify(() => repository.update(name: 'Novo nome')).called(1);
      when(() => repository.update(name: any(named: 'name')))
          .thenAnswer((_) async => user);
      await tester.tap(button());
      await tester.pumpAndSettle();
      verify(() => repository.update(name: 'Outro nome')).called(1);
      expect(updated, [same(user)]);
    },
  );

  testWidgets('field-only errors do not also create a toast', (tester) async {
    when(() => repository.update(name: any(named: 'name'))).thenAnswer(
      (_) async => throw UserException(
        errors: const ErrorsEntity(
          errors: [
            ErrorEntity(status: '422', pointer: '/data/attributes/name'),
          ],
        ),
      ),
    );
    await pumpScreen(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(fieldFailure(tester), 'Nome inválido.');
    expect(
      ToastProviderWidget.of(tester.element(find.byType(EditUserScreen))).toast,
      isNull,
    );
  });

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(errors: [ErrorEntity()]),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '500',
          pointer: '/data/attributes/name',
          detail: 'Falha remota',
        ),
      ],
    ),
  ]) {
    testWidgets('safe toast without a field error for ${errors.errors}', (
      tester,
    ) async {
      when(() => repository.update(name: any(named: 'name')))
          .thenAnswer((_) async => throw UserException(errors: errors));
      await pumpScreen(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Erro ao atualizar nome'), findsOneWidget);
      expect(fieldFailure(tester), isNull);
      expect(text(tester), '  Novo nome  ');
      expect(updated, isEmpty);
    });
  }

  testWidgets(
    'unexpected errors do not expose internal details or confirm success',
    (tester) async {
      when(() => repository.update(name: any(named: 'name')))
          .thenAnswer((_) async => throw StateError('internal secret'));
      await pumpScreen(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Erro desconhecido'), findsOneWidget);
      expect(find.textContaining('internal secret'), findsNothing);
      expect(updated, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    },
  );

  testWidgets(
    'rebuild retains input and the same owned Bloc without requests',
    (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), '  Rascunho  ');
      await pumpScreen(tester);
      expect(text(tester), '  Rascunho  ');
      expect(blocs, hasLength(1));
      verifyZeroInteractions(repository);
    },
  );

  for (final replace in [false, true]) {
    for (final outcome in ['success', 'expected', 'unexpected']) {
      testWidgets(
        '${replace ? 'replacement' : 'disposal'} ignores pending $outcome',
        (tester) async {
          final pending = hold();
          await pumpScreen(tester);
          await submit(tester);
          final old = blocs.single;
          if (replace) {
            EditBloc replacement() => createBloc();
            await pumpScreen(tester, blocFactory: replacement);
            expect(text(tester), '  Novo nome  ');
          } else {
            await tester.pumpWidget(const SizedBox.shrink());
          }
          expect(old.isClosed, isTrue);
          switch (outcome) {
            case 'success':
              pending.complete(user);
            case 'expected':
              pending.completeError(
                UserException(errors: const ErrorsEntity(errors: [])),
              );
            default:
              pending.completeError(StateError('late error'));
          }
          await tester.pumpAndSettle();
          expect(updated, isEmpty);
          expect(tester.takeException(), isNull);
          if (replace) {
            expect(
              ToastProviderWidget.of(
                tester.element(find.byType(EditUserScreen)),
              ).toast,
              isNull,
            );
          }
        },
      );
    }
  }

  testWidgets(
    'large text and keyboard preserve scrollable editing without overflow',
    (tester) async {
      await pumpScreen(tester, textScale: 2);
      await tester.enterText(find.byType(TextField), 'Outro nome');
      await tester.pump();
      await tester.ensureVisible(find.byType(TextField));
      expect(tester.takeException(), isNull);
      expect(tester.widget<ElevatedButton>(button()).onPressed, isNotNull);
    },
  );
}
