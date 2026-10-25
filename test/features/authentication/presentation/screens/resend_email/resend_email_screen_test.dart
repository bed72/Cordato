import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const email = ' Person@Example.com ';
  const rejected = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '429',
        title: 'Aguarde',
        detail: 'Limite de reenvios atingido.',
      ),
      ErrorEntity(detail: 'Confira o endereço informado.'),
    ],
  );
  late AuthenticationRepositoryMock repository;
  late List<ResendEmailBloc> blocs;
  late List<Completer<void>> requests;
  late ResendEmailBloc Function() factory;
  late bool prepared;

  ResendEmailBloc createBloc() {
    final bloc = ResendEmailBloc(repository: repository);
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
    String address = email,
    ResendEmailBloc Function()? blocFactory,
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
          child: ResendEmailScreen(
            email: address,
            bloc: blocFactory ?? factory,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ElevatedButton button(WidgetTester tester) =>
      tester.widget(find.byType(ElevatedButton));

  Future<void> expireCooldown(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
  }

  Future<void> resend(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  void stub(Future<void> Function() answer) {
    when(() => repository.resendEmail(email: any(named: 'email')))
        .thenAnswer((_) => answer());
  }

  Completer<void> hold() {
    final pending = Completer<void>();
    requests.add(pending);
    stub(() => pending.future);
    return pending;
  }

  testWidgets(
    'starts with a read-only email and 60 second cooldown without sending',
    (tester) async {
      await pumpScreen(tester);
      expect(find.text('Verifique seu e-mail'), findsOneWidget);
      expect(find.text('Você poderá reenviar em 60 segundos'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(field.controller!.text, email);
      expect(button(tester).onPressed, isNull);
      await resend(tester);
      await tester.pump(const Duration(seconds: 58));
      expect(button(tester).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Você poderá reenviar em 1 segundo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(button(tester).onPressed, isNotNull);
      expect(find.textContaining('Você poderá reenviar'), findsNothing);
      verifyZeroInteractions(repository);
    },
  );

  testWidgets('an empty email stays disabled after cooldown expires', (
    tester,
  ) async {
    await pumpScreen(tester, address: '');
    await expireCooldown(tester);
    expect(button(tester).onPressed, isNull);
    await resend(tester);
    verifyZeroInteractions(repository);
  });

  testWidgets(
    'success restarts cooldown, shows feedback once and allows a later resend',
    (tester) async {
      final pending = hold();
      await pumpScreen(tester);
      await expireCooldown(tester);
      await resend(tester);
      expect(button(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await resend(tester);
      await tester.pump(const Duration(seconds: 65));
      expect(button(tester).onPressed, isNull);
      verify(() => repository.resendEmail(email: email)).called(1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('E-mail reenviado'), findsOneWidget);
      expect(
        find.text('Confira sua caixa de entrada para confirmar seu e-mail.'),
        findsOneWidget,
      );
      expect(find.text('Você poderá reenviar em 60 segundos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final notifier = ToastProviderWidget.of(
        tester.element(find.byType(ResendEmailScreen)),
      );
      final feedbackId = notifier.toast!.id;
      await pumpScreen(tester);
      expect(blocs, hasLength(1));
      expect(notifier.toast!.id, feedbackId);
      await tester.pump(const Duration(seconds: 10));
      await pumpScreen(tester);
      expect(find.text('Você poderá reenviar em 50 segundos'), findsOneWidget);
      verifyNoMoreInteractions(repository);
      await expireCooldown(tester);
      expect(button(tester).onPressed, isNotNull);
      stub(() async {});
      await resend(tester);
      await tester.pumpAndSettle();
      expect(find.text('E-mail reenviado'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      verify(() => repository.resendEmail(email: email)).called(1);
    },
  );

  testWidgets(
    'remote failure preserves all feedback and allows immediate manual retry',
    (tester) async {
      stub(() async => throw AuthenticationException(errors: rejected));
      await pumpScreen(tester);
      await expireCooldown(tester);
      await resend(tester);
      await tester.pumpAndSettle();
      expect(find.text('Aguarde'), findsOneWidget);
      expect(
        find.text(
          'Limite de reenvios atingido.\nConfira o endereço informado.',
        ),
        findsOneWidget,
      );
      expect(button(tester).onPressed, isNotNull);
      expect(find.textContaining('Você poderá reenviar'), findsNothing);
      final notifier = ToastProviderWidget.of(
        tester.element(find.byType(ResendEmailScreen)),
      );
      final feedbackId = notifier.toast!.id;
      await pumpScreen(tester);
      expect(notifier.toast!.id, feedbackId);
      await tester.pump(const Duration(seconds: 7));
      verify(() => repository.resendEmail(email: email)).called(1);
      stub(() async {});
      await resend(tester);
      await tester.pumpAndSettle();
      expect(find.text('E-mail reenviado'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      verify(() => repository.resendEmail(email: email)).called(1);
    },
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(errors: [ErrorEntity()]),
  ]) {
    testWidgets(
      'uses safe fallback for ${errors.errors.length} incomplete errors',
      (tester) async {
        stub(() async => throw AuthenticationException(errors: errors));
        await pumpScreen(tester);
        await expireCooldown(tester);
        await resend(tester);
        await tester.pumpAndSettle();
        expect(find.text('Erro ao reenviar e-mail'), findsOneWidget);
        expect(
          find.text(
            errors.errors.isEmpty
                ? 'Não foi possível reenviar o e-mail. Tente novamente.'
                : 'Não foi possível reenviar o e-mail.',
          ),
          findsOneWidget,
        );
        expect(button(tester).onPressed, isNotNull);
      },
    );
  }

  testWidgets('unexpected errors use safe feedback and allow retry', (
    tester,
  ) async {
    stub(() async => throw StateError('internal secret'));
    await pumpScreen(tester);
    await expireCooldown(tester);
    await resend(tester);
    await tester.pumpAndSettle();
    expect(find.text('Erro desconhecido'), findsOneWidget);
    expect(find.textContaining('internal secret'), findsNothing);
    expect(button(tester).onPressed, isNotNull);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'factory replacement ignores late ${fails ? 'failure' : 'success'} without resetting cooldown',
      (tester) async {
        final pending = hold();
        await pumpScreen(tester);
        await expireCooldown(tester);
        await resend(tester);
        final previous = blocs.single;
        ResendEmailBloc replacement() => createBloc();
        await pumpScreen(tester, blocFactory: replacement);
        expect(previous.isClosed, isTrue);
        expect(blocs, hasLength(2));
        expect(blocs.last.isClosed, isFalse);
        expect(button(tester).onPressed, isNotNull);
        if (fails) {
          pending.completeError(AuthenticationException(errors: rejected));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        final notifier = ToastProviderWidget.of(
          tester.element(find.byType(ResendEmailScreen)),
        );
        expect(notifier.toast, isNull);
        expect(button(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fails in [false, true]) {
    testWidgets(
      'dispose closes bloc and ignores late ${fails ? 'failure' : 'success'}',
      (tester) async {
        final pending = hold();
        await pumpScreen(tester);
        await expireCooldown(tester);
        await resend(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(blocs.single.isClosed, isTrue);
        if (fails) {
          pending.completeError(AuthenticationException(errors: rejected));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disposing during initial cooldown cancels the timer', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 65));
    expect(blocs.single.isClosed, isTrue);
    expect(tester.takeException(), isNull);
    verifyZeroInteractions(repository);
  });
}
