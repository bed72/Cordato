import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/widgets/user_avatar_widget.dart';

import '../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  const profile = UserEntity(
    id: '1',
    name: 'Pessoa',
    email: 'person@example.com',
    status: 'active',
    avatar: 'initial',
  );
  late UserRepositoryMock repository;
  late List<UserBloc> blocs;
  late UserBloc Function() factory;
  late List<Completer<UserEntity>> pendingUsers;
  late List<Completer<void>> pendingDeletes;
  late bool prepared;

  UserBloc createBloc() {
    final bloc = UserBloc(repository: repository);
    blocs.add(bloc);
    return bloc;
  }

  setUp(() {
    repository = UserRepositoryMock();
    blocs = [];
    pendingUsers = [];
    pendingDeletes = [];
    factory = createBloc;
    prepared = false;
    when(() => repository.getById()).thenAnswer((_) async => profile);
    when(() => repository.delete()).thenAnswer((_) async {});
    when(() => repository.update(avatar: any(named: 'avatar'))).thenAnswer(
      (invocation) async => UserEntity(
        id: profile.id,
        name: profile.name,
        email: profile.email,
        status: profile.status,
        avatar: invocation.namedArguments[#avatar] as String,
      ),
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    UserBloc Function()? blocFactory,
    Future<UserEntity?> Function(String)? onNamePressed,
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
        for (final pending in pendingUsers) {
          if (!pending.isCompleted) pending.complete(profile);
        }
        for (final pending in pendingDeletes) {
          if (!pending.isCompleted) pending.complete();
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
            child: UserScreen(
              bloc: blocFactory ?? factory,
              onBackPressed: (_) {},
              onNamePressed: onNamePressed ?? (_) async => null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  UserAvatarWidget avatar(WidgetTester tester) =>
      tester.widget<UserAvatarWidget>(find.byType(UserAvatarWidget));
  Finder deleteButton() => find.descendant(
    of: find.byType(DangerButtonWidget),
    matching: find.byType(ElevatedButton),
  );
  Finder confirmButton() => find.descendant(
    of: find.byType(ConfirmationBottomSheetWidget),
    matching: find.byType(ElevatedButton),
  );
  Future<void> generate(WidgetTester tester) async {
    avatar(tester).onPressed!();
    await tester.pump();
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.tap(deleteButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(confirmButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets(
    'loads once, preserves the instance on rebuild and closes on removal',
    (tester) async {
      await pumpScreen(tester);
      expect(find.text('Pessoa'), findsOneWidget);
      expect(find.text('person@example.com'), findsOneWidget);
      expect(avatar(tester).seed, 'initial');
      await pumpScreen(tester);
      expect(blocs, hasLength(1));
      verify(() => repository.getById()).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(blocs.single.isClosed, isTrue);
    },
  );

  testWidgets('pending load hides skeleton semantics and disables mutations', (
    tester,
  ) async {
    final pending = Completer<UserEntity>();
    pendingUsers.add(pending);
    when(() => repository.getById()).thenAnswer((_) => pending.future);
    await pumpScreen(tester);
    expect(blocs.single.state, isA<UserLoading>());
    expect(avatar(tester).onPressed, isNull);
    expect(tester.widget<ElevatedButton>(deleteButton()).onPressed, isNull);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Avatar de Nome do usuário'), findsNothing);
    semantics.dispose();
    pending.complete(profile);
    await tester.pumpAndSettle();
    expect(find.text('Pessoa'), findsOneWidget);
  });

  for (final errors in [
    const ErrorsEntity(errors: [ErrorEntity(detail: 'Perfil indisponível')]),
    const ErrorsEntity(errors: []),
  ]) {
    testWidgets(
      'load failure uses ErrorScreen and supports manual retry: ${errors.errors.length}',
      (tester) async {
        when(() => repository.getById())
            .thenAnswer((_) async => throw UserException(errors: errors));
        await pumpScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byType(ErrorScreen), findsOneWidget);
        expect(
          find.text(
            errors.errors.isEmpty
                ? 'Não foi possível processar a resposta.'
                : 'Perfil indisponível',
          ),
          findsOneWidget,
        );
        when(() => repository.getById()).thenAnswer((_) async => profile);
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();
        expect(find.text('Pessoa'), findsOneWidget);
        verify(() => repository.getById()).called(2);
      },
    );
  }

  testWidgets(
    'avatar debounce saves only the last seed and shows feedback once',
    (tester) async {
      await pumpScreen(tester);
      await generate(tester);
      final first = avatar(tester).seed;
      await tester.pump(const Duration(seconds: 1));
      verifyNever(() => repository.update(avatar: any(named: 'avatar')));
      await generate(tester);
      final last = avatar(tester).seed;
      expect(last, isNot(first));
      await tester.pump(const Duration(seconds: 1));
      verifyNever(() => repository.update(avatar: any(named: 'avatar')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      verify(() => repository.update(avatar: last)).called(1);
      expect(avatar(tester).seed, last);
      expect(find.text('Avatar atualizado'), findsOneWidget);
      final notifier = ToastProviderWidget.of(
        tester.element(find.byType(UserScreen)),
      );
      final id = notifier.toast!.id;
      await pumpScreen(tester);
      expect(notifier.toast!.id, id);
      expect(blocs, hasLength(1));
      verifyNever(() => repository.update(avatar: any(named: 'avatar')));
    },
  );

  testWidgets(
    'avatar pending disables editing and deletion without losing the profile',
    (tester) async {
      final pending = Completer<UserEntity>();
      pendingUsers.add(pending);
      when(() => repository.update(avatar: any(named: 'avatar')))
          .thenAnswer((_) => pending.future);
      var edits = 0;
      await pumpScreen(
        tester,
        onNamePressed: (_) async {
          edits++;
          return null;
        },
      );
      await generate(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(blocs.single.state, isA<UserAvatarSaving>());
      expect(find.text('Pessoa'), findsOneWidget);
      expect(avatar(tester).onPressed, isNull);
      expect(tester.widget<ElevatedButton>(deleteButton()).onPressed, isNull);
      await tester.tap(find.text('Nome'));
      await tester.pump();
      expect(edits, 0);
    },
  );

  testWidgets(
    'failed avatar preserves the seed and allows a new manual attempt',
    (tester) async {
      when(() => repository.update(avatar: any(named: 'avatar'))).thenAnswer(
        (_) async => throw UserException(
          errors: const ErrorsEntity(
            errors: [ErrorEntity(detail: 'Avatar recusado')],
          ),
        ),
      );
      await pumpScreen(tester);
      await generate(tester);
      final seed = avatar(tester).seed;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(avatar(tester).seed, seed);
      expect(find.text('Avatar recusado'), findsOneWidget);
      expect(find.text('Pessoa'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      verify(() => repository.update(avatar: seed)).called(1);
      await generate(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      verify(() => repository.update(avatar: any(named: 'avatar'))).called(1);
    },
  );

  testWidgets('deletion requires confirmation and cancel has no effect', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openConfirmation(tester);
    expect(find.text('Deseja apagar sua conta?'), findsOneWidget);
    verifyNever(() => repository.delete());
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.delete());
  });

  testWidgets(
    'confirmed deletion cancels debounce, blocks actions and leaves navigation to Session',
    (tester) async {
      final pending = Completer<void>();
      pendingDeletes.add(pending);
      when(() => repository.delete()).thenAnswer((_) => pending.future);
      await pumpScreen(tester);
      await generate(tester);
      await openConfirmation(tester);
      await confirm(tester);
      expect(blocs.single.state, isA<UserDeleting>());
      expect(tester.widget<ElevatedButton>(deleteButton()).onPressed, isNull);
      expect(avatar(tester).onPressed, isNull);
      await tester.pump(const Duration(seconds: 3));
      verifyNever(() => repository.update(avatar: any(named: 'avatar')));
      verify(() => repository.delete()).called(1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(UserScreen), findsOneWidget);
      expect(tester.widget<ElevatedButton>(deleteButton()).onPressed, isNull);
      expect(
        ToastProviderWidget.of(tester.element(find.byType(UserScreen))).toast,
        isNull,
      );
    },
  );

  for (final rejected in [false, true]) {
    testWidgets(
      'deletion ${rejected ? 'remote' : 'safe fallback'} failure gives feedback and requires confirmation for retry',
      (tester) async {
        when(() => repository.delete()).thenAnswer((_) async {
          if (rejected) {
            throw UserException(
              errors: const ErrorsEntity(
                errors: [
                  ErrorEntity(
                    title: 'Conta mantida',
                    detail: 'Não foi possível excluir.',
                  ),
                ],
              ),
            );
          }
          throw UserException(errors: ErrorsEntity.unknown());
        });
        await pumpScreen(tester);
        await openConfirmation(tester);
        await confirm(tester);
        await tester.pumpAndSettle();
        expect(blocs.single.state, isA<UserDeleteFailure>());
        expect(find.text('Pessoa'), findsOneWidget);
        expect(
          find.text(rejected ? 'Conta mantida' : 'Erro desconhecido'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 7));
        verify(() => repository.delete()).called(1);
        when(() => repository.delete()).thenAnswer((_) async {});
        await openConfirmation(tester);
        verifyNever(() => repository.delete());
        await confirm(tester);
        await tester.pumpAndSettle();
        verify(() => repository.delete()).called(1);
      },
    );
  }

  testWidgets('factory replacement invalidates an open confirmation', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openConfirmation(tester);
    final old = blocs.single;
    UserBloc replacement() => createBloc();
    await pumpScreen(tester, blocFactory: replacement);
    expect(old.isClosed, isTrue);
    await confirm(tester);
    await tester.pumpAndSettle();
    verifyNever(() => repository.delete());
    expect(blocs, hasLength(2));
  });

  testWidgets('factory replacement cancels a scheduled avatar save', (
    tester,
  ) async {
    await pumpScreen(tester);
    await generate(tester);
    final old = blocs.single;
    UserBloc replacement() => createBloc();
    await pumpScreen(tester, blocFactory: replacement);
    await tester.pump(const Duration(seconds: 3));
    expect(old.isClosed, isTrue);
    expect(avatar(tester).seed, 'initial');
    verifyNever(() => repository.update(avatar: any(named: 'avatar')));
  });

  testWidgets('disposal cancels the timer without saving', (tester) async {
    await pumpScreen(tester);
    await generate(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    verifyNever(() => repository.update(avatar: any(named: 'avatar')));
    expect(blocs.single.isClosed, isTrue);
  });

  for (final operation in ['load', 'avatar', 'delete']) {
    testWidgets('removing during pending $operation ignores late completion', (
      tester,
    ) async {
      final user = Completer<UserEntity>();
      final deletion = Completer<void>();
      pendingUsers.add(user);
      pendingDeletes.add(deletion);
      if (operation == 'load') {
        when(() => repository.getById()).thenAnswer((_) => user.future);
      }
      if (operation == 'avatar') {
        when(() => repository.update(avatar: any(named: 'avatar')))
            .thenAnswer((_) => user.future);
      }
      if (operation == 'delete') {
        when(() => repository.delete()).thenAnswer((_) => deletion.future);
      }
      await pumpScreen(tester);
      if (operation == 'avatar') {
        await generate(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
      if (operation == 'delete') {
        await openConfirmation(tester);
        await confirm(tester);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      user.complete(profile);
      deletion.complete();
      await tester.pumpAndSettle();
      expect(blocs.single.isClosed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('return from name editing reloads only after confirmed change', (
    tester,
  ) async {
    var changed = false;
    Future<UserEntity?> edit(String name) async {
      expect(name, 'Pessoa');
      return changed ? profile : null;
    }

    await pumpScreen(tester, onNamePressed: edit);
    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    verify(() => repository.getById()).called(1);
    changed = true;
    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    verify(() => repository.getById()).called(1);
  });

  for (final operation in ['load', 'avatar', 'delete']) {
    testWidgets(
      'replacing the factory during $operation ignores the old result',
      (tester) async {
        final pendingUser = Completer<UserEntity>();
        final pendingDelete = Completer<void>();
        pendingUsers.add(pendingUser);
        pendingDeletes.add(pendingDelete);
        if (operation == 'load') {
          when(() => repository.getById())
              .thenAnswer((_) => pendingUser.future);
        }
        if (operation == 'avatar') {
          when(() => repository.update(avatar: any(named: 'avatar')))
              .thenAnswer((_) => pendingUser.future);
        }
        if (operation == 'delete') {
          when(() => repository.delete())
              .thenAnswer((_) => pendingDelete.future);
        }
        await pumpScreen(tester);
        if (operation == 'avatar') {
          await generate(tester);
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
        }
        if (operation == 'delete') {
          await openConfirmation(tester);
          await confirm(tester);
        }
        final old = blocs.single;
        when(() => repository.getById()).thenAnswer((_) async => profile);
        UserBloc replacement() => createBloc();
        await pumpScreen(tester, blocFactory: replacement);
        expect(old.isClosed, isTrue);
        if (operation == 'delete') {
          pendingUser.complete(profile);
        } else {
          pendingUser.completeError(
            UserException(errors: const ErrorsEntity(errors: [])),
          );
        }
        pendingDelete.complete();
        await tester.pumpAndSettle();
        expect(find.text('Pessoa'), findsOneWidget);
        expect(blocs.last.state, isA<UserReady>());
        expect(
          ToastProviderWidget.of(tester.element(find.byType(UserScreen))).toast,
          isNull,
        );
      },
    );
  }

  testWidgets('large text remains scrollable without overflow', (tester) async {
    await pumpScreen(tester, textScale: 2);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('person@example.com'));
    expect(tester.takeException(), isNull);
  });
}
