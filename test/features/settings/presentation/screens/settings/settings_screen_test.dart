import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_logout_widget.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const rejected = ErrorsEntity(
    errors: [
      ErrorEntity(
        title: 'Sessão mantida',
        detail: 'Não foi possível revogar o acesso.',
      ),
      ErrorEntity(detail: 'Tente mais tarde.'),
    ],
  );
  late AuthenticationRepositoryMock repository;
  late List<LogoutBloc> blocs;
  late List<Completer<void>> requests;
  late LogoutBloc Function() factory;
  late bool prepared;

  LogoutBloc createBloc() {
    final bloc = LogoutBloc(repository: repository);
    blocs.add(bloc);
    return bloc;
  }

  setUp(() {
    repository = AuthenticationRepositoryMock();
    blocs = [];
    requests = [];
    factory = createBloc;
    prepared = false;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    LogoutBloc Function()? blocFactory,
  }) async {
    if (!prepared) {
      prepared = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final pending in requests) {
          if (!pending.isCompleted) pending.complete();
        }
        await tester.pumpAndSettle();
        for (final bloc in blocs) {
          expect(bloc.isClosed, isTrue);
        }
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: Themes.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ToastProviderWidget(
          child: SettingsScreen(
            bloc: blocFactory ?? factory,
            onBackPressed: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder logoutButton() => find.descendant(
    of: find.byType(SettingsLogoutWidget),
    matching: find.byType(ElevatedButton),
  );
  Finder confirmButton() => find.descendant(
    of: find.byType(ConfirmationBottomSheetWidget),
    matching: find.byType(ElevatedButton),
  );

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.tap(logoutButton());
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(confirmButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Completer<void> hold() {
    final pending = Completer<void>();
    requests.add(pending);
    when(() => repository.logout()).thenAnswer((_) => pending.future);
    return pending;
  }

  testWidgets('opening and cancelling confirmation does not log out', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Configurações'), findsOneWidget);
    await openConfirmation(tester);
    expect(find.text('Realmente deseja sair?'), findsOneWidget);
    expect(
      find.text(
        'Ao sair da sua conta, você precisará fazer login novamente para acessar o Trocado.',
      ),
      findsOneWidget,
    );
    verifyZeroInteractions(repository);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmationBottomSheetWidget), findsNothing);
    expect(tester.widget<ElevatedButton>(logoutButton()).onPressed, isNotNull);
    verifyZeroInteractions(repository);
  });

  testWidgets(
    'confirmed logout blocks duplicates and leaves navigation to session observation',
    (tester) async {
      final pending = hold();
      await pumpScreen(tester);
      await openConfirmation(tester);
      await confirm(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<ElevatedButton>(logoutButton()).onPressed, isNull);
      await tester.tap(logoutButton());
      await tester.pump();
      expect(find.byType(ConfirmationBottomSheetWidget), findsNothing);
      verify(() => repository.logout()).called(1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<ElevatedButton>(logoutButton()).onPressed, isNull);
      expect(
        ToastProviderWidget.of(tester.element(find.byType(SettingsScreen)))
            .toast,
        isNull,
      );
      verifyNoMoreInteractions(repository);
    },
  );

  testWidgets(
    'remote errors show one toast and require confirmation again for manual retry',
    (tester) async {
      when(() => repository.logout()).thenAnswer(
        (_) async => throw AuthenticationException(errors: rejected),
      );
      await pumpScreen(tester);
      await openConfirmation(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(find.text('Sessão mantida'), findsOneWidget);
      expect(
        find.text('Não foi possível revogar o acesso.\nTente mais tarde.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(logoutButton()).onPressed,
        isNotNull,
      );
      final notifier = ToastProviderWidget.of(
        tester.element(find.byType(SettingsScreen)),
      );
      final feedbackId = notifier.toast!.id;
      await pumpScreen(tester);
      expect(blocs, hasLength(1));
      expect(notifier.toast!.id, feedbackId);
      await tester.pump(const Duration(seconds: 7));
      verify(() => repository.logout()).called(1);
      when(() => repository.logout()).thenAnswer((_) async {});
      await openConfirmation(tester);
      verifyNoMoreInteractions(repository);
      await confirm(tester);
      await tester.pumpAndSettle();
      verify(() => repository.logout()).called(1);
      expect(tester.widget<ElevatedButton>(logoutButton()).onPressed, isNull);
    },
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(errors: [ErrorEntity()]),
  ]) {
    testWidgets(
      'uses safe feedback for ${errors.errors.length} incomplete errors',
      (tester) async {
        when(() => repository.logout()).thenAnswer(
          (_) async => throw AuthenticationException(errors: errors),
        );
        await pumpScreen(tester);
        await openConfirmation(tester);
        await confirm(tester);
        await tester.pumpAndSettle();
        expect(find.text('Erro ao sair'), findsOneWidget);
        expect(
          find.text('Não foi possível sair. Tente novamente.'),
          findsOneWidget,
        );
        expect(
          tester.widget<ElevatedButton>(logoutButton()).onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets(
    'unexpected errors use safe feedback without confirming success',
    (tester) async {
      when(() => repository.logout())
          .thenAnswer((_) async => throw StateError('internal secret'));
      await pumpScreen(tester);
      await openConfirmation(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(find.text('Erro desconhecido'), findsOneWidget);
      expect(find.textContaining('internal secret'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(logoutButton()).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'replacing the factory while confirming cannot submit through either owner',
    (tester) async {
      await pumpScreen(tester);
      await openConfirmation(tester);
      final previous = blocs.single;
      LogoutBloc replacement() => createBloc();
      await pumpScreen(tester, blocFactory: replacement);
      expect(previous.isClosed, isTrue);
      expect(blocs, hasLength(2));
      await confirm(tester);
      await tester.pumpAndSettle();
      verifyZeroInteractions(repository);
      expect(
        tester.widget<ElevatedButton>(logoutButton()).onPressed,
        isNotNull,
      );
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'replacing the factory ignores pending ${fails ? 'failure' : 'success'}',
      (tester) async {
        final pending = hold();
        await pumpScreen(tester);
        await openConfirmation(tester);
        await confirm(tester);
        final previous = blocs.single;
        LogoutBloc replacement() => createBloc();
        await pumpScreen(tester, blocFactory: replacement);
        expect(previous.isClosed, isTrue);
        expect(blocs, hasLength(2));
        if (fails) {
          pending.completeError(AuthenticationException(errors: rejected));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(
          ToastProviderWidget.of(tester.element(find.byType(SettingsScreen)))
              .toast,
          isNull,
        );
        expect(
          tester.widget<ElevatedButton>(logoutButton()).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fails in [false, true]) {
    testWidgets('disposing ignores late ${fails ? 'failure' : 'success'}', (
      tester,
    ) async {
      final pending = hold();
      await pumpScreen(tester);
      await openConfirmation(tester);
      await confirm(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(blocs.single.isClosed, isTrue);
      if (fails) {
        pending.completeError(AuthenticationException(errors: rejected));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
