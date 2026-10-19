import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_notifier.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const password = 'Teste1';
  const email = 'Person@Example.com';

  const rejected = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '401',
        title: 'Credenciais inválidas',
        detail: 'E-mail ou senha incorretos.',
      ),
    ],
  );

  const fieldErrors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '422',
        pointer: '/data/attributes/email',
        detail: 'E-mail rejeitado pela API.',
      ),
      ErrorEntity(
        status: '422',
        detail: 'Senha rejeitada pela API.',
        pointer: '/data/attributes/password',
      ),
    ],
  );

  late bool prepared;
  late List<SignInBloc> blocs;
  late SignInBloc Function() factory;
  late List<Completer<void>> pendingRequests;
  late AuthenticationRepositoryMock repository;

  SignInBloc createBloc() {
    final bloc = SignInBloc(repository: repository);
    blocs.add(bloc);

    return bloc;
  }

  setUp(() {
    prepared = false;

    blocs = [];
    pendingRequests = [];
    factory = createBloc;

    repository = AuthenticationRepositoryMock();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    SignInBloc Function()? blocFactory,
  }) async {
    if (!prepared) {
      prepared = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        for (final pending in pendingRequests) {
          if (!pending.isCompleted) pending.complete();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
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
          child: SignInScreen(
            bloc: blocFactory ?? factory,
            emailValidation: const EmailValidation(),
            passwordValidation: const PasswordValidation(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String enteredEmail = email,
    String enteredPassword = password,
  }) async {
    await tester.enterText(find.byType(TextField).at(0), enteredEmail);
    await tester.enterText(find.byType(TextField).at(1), enteredPassword);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  ToastNotifier toast(WidgetTester tester) =>
      ToastProviderWidget.of(tester.element(find.byType(SignInScreen)));

  List<TextField> fields(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).toList();

  Completer<void> holdRequest() {
    final pending = Completer<void>();
    pendingRequests.add(pending);
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    return pending;
  }

  void rejectWith(ErrorsEntity errors) {
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => throw AuthenticationException(errors: errors));
  }

  testWidgets('shows the initial form without authenticating', (tester) async {
    await pumpScreen(tester);

    expect(toast(tester).toast, isNull);
    expect(fields(tester).last.obscureText, isTrue);
    expect(find.text('Crie agora'), findsOneWidget);
    expect(find.text('Digite sua senha'), findsOneWidget);
    expect(find.text('Digite seu e-mail'), findsOneWidget);
    expect(find.text('Que bom ter você por aqui'), findsOneWidget);
    expect(find.text('Entre com seu e-mail e senha'), findsOneWidget);
    expect(fields(tester).every((field) => field.enabled == true), isTrue);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    verifyZeroInteractions(repository);
  });

  testWidgets('shows both required errors without calling the repository', (
    tester,
  ) async {
    await pumpScreen(tester);
    await submit(tester);

    expect(find.text('Senha obrigatória'), findsOneWidget);
    expect(find.text('E-mail obrigatório'), findsOneWidget);
    verifyZeroInteractions(repository);
  });

  for (final scenario in [
    (email: 'pessoa@exemplo', password: password, message: 'E-mail inválido'),
    (
      email: email,
      password: 'Abc12',
      message: 'A senha deve ter entre 6 e 12 caracteres',
    ),
    (
      email: email,
      password: 'Abcdefghijk12',
      message: 'A senha deve ter entre 6 e 12 caracteres',
    ),
    (
      email: email,
      password: 'teste1',
      message: 'A senha deve conter uma letra maiúscula',
    ),
    (
      email: email,
      password: 'Testee',
      message: 'A senha deve conter um número',
    ),
  ]) {
    testWidgets('rejects ${scenario.email}/${scenario.password} locally', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillForm(
        tester,
        enteredEmail: scenario.email,
        enteredPassword: scenario.password,
      );
      await submit(tester);

      expect(find.text(scenario.message), findsOneWidget);
      verifyZeroInteractions(repository);
    });
  }

  testWidgets('editing clears only the corresponding field error', (
    tester,
  ) async {
    await pumpScreen(tester);
    await submit(tester);
    await tester.enterText(find.byType(TextField).first, email);
    await tester.pump();

    expect(find.text('E-mail obrigatório'), findsNothing);
    expect(find.text('Senha obrigatória'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, password);
    await tester.pump();

    expect(find.text('Senha obrigatória'), findsNothing);
    verifyZeroInteractions(repository);
  });

  testWidgets(
    'submits trimmed email and unchanged password while disabling input',
    (tester) async {
      final pending = holdRequest();
      await pumpScreen(tester);
      await fillForm(
        tester,
        enteredEmail: ' $email ',
        enteredPassword: ' $password ',
      );
      await submit(tester);

      expect(fields(tester).every((field) => field.enabled == false), isTrue);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(() => repository.signIn(email: email, password: ' $password '))
          .called(1);

      pending.complete();
      await tester.pumpAndSettle();

      expect(toast(tester).toast, isNull);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fields(tester).every((field) => field.enabled == false), isTrue);
      verifyNoMoreInteractions(repository);
    },
  );

  testWidgets(
    'submits from the password keyboard action only once while busy',
    (tester) async {
      final pending = holdRequest();
      await pumpScreen(tester);
      await fillForm(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await submit(tester);

      verify(() => repository.signIn(email: email, password: password))
          .called(1);
      expect(fields(tester).every((field) => field.enabled == false), isTrue);

      pending.complete();
      await tester.pumpAndSettle();
      verifyNoMoreInteractions(repository);
    },
  );

  testWidgets(
    'maps backend validation errors to fields without showing a toast',
    (tester) async {
      rejectWith(fieldErrors);
      await pumpScreen(tester);
      await fillForm(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Senha rejeitada pela API.'), findsOneWidget);
      expect(find.text('E-mail rejeitado pela API.'), findsOneWidget);

      expect(toast(tester).toast, isNull);
      expect(fields(tester).first.controller!.text, email);
      expect(fields(tester).last.controller!.text, password);
      expect(fields(tester).every((field) => field.enabled == true), isTrue);

      await tester.enterText(find.byType(TextField).first, 'other@example.com');
      await tester.pump();

      expect(find.text('E-mail rejeitado pela API.'), findsNothing);
      expect(find.text('Senha rejeitada pela API.'), findsOneWidget);
    },
  );

  testWidgets('shows field errors and remaining backend errors together', (
    tester,
  ) async {
    rejectWith(
      ErrorsEntity(errors: [fieldErrors.errors.first, rejected.errors.first]),
    );

    await pumpScreen(tester);
    await fillForm(tester);
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Credenciais inválidas'), findsOneWidget);
    expect(find.text('E-mail rejeitado pela API.'), findsOneWidget);
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(errors: [ErrorEntity()]),
  ]) {
    testWidgets(
      'uses safe feedback for backend errors ${errors.errors.length}',
      (tester) async {
        rejectWith(errors);
        await pumpScreen(tester);
        await fillForm(tester);
        await submit(tester);
        await tester.pumpAndSettle();

        expect(find.text('Erro ao entrar'), findsOneWidget);
        expect(fields(tester).every((field) => field.enabled == true), isTrue);
        expect(
          find.text('Não foi possível entrar. Tente novamente.'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('unexpected failures show safe feedback and allow retry', (
    tester,
  ) async {
    when(() => repository.signIn(email: email, password: password))
        .thenAnswer((_) async => throw StateError('internal secret'));
    await pumpScreen(tester);
    await fillForm(tester);
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Erro desconhecido'), findsOneWidget);
    expect(find.textContaining('internal secret'), findsNothing);
    expect(fields(tester).every((field) => field.enabled == true), isTrue);
    expect(find.text('Não foi possível processar a resposta.'), findsOneWidget);
  });

  testWidgets(
    'preserves input for manual retry without repeating feedback on rebuild',
    (tester) async {
      rejectWith(rejected);
      await pumpScreen(tester);
      await fillForm(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      final notifier = toast(tester);
      final feedbackId = notifier.toast!.id;

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(blocs, hasLength(1));
      expect(notifier.toast!.id, feedbackId);
      expect(fields(tester).first.controller!.text, email);
      expect(fields(tester).last.controller!.text, password);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      expect(notifier.toast, isNull);
      verify(() => repository.signIn(email: email, password: password))
          .called(1);

      when(() => repository.signIn(email: email, password: password))
          .thenAnswer((_) async {});
      await submit(tester);
      await tester.pumpAndSettle();

      expect(notifier.toast, isNull);
      expect(fields(tester).every((field) => field.enabled == false), isTrue);
      verify(() => repository.signIn(email: email, password: password))
          .called(1);
    },
  );

  testWidgets(
    'replacing the factory closes the old bloc and ignores its late error',
    (tester) async {
      final pending = holdRequest();
      await pumpScreen(tester);
      await fillForm(tester);
      await submit(tester);
      final previousBloc = blocs.single;
      SignInBloc replacementFactory() => createBloc();

      await pumpScreen(tester, blocFactory: replacementFactory);

      expect(blocs, hasLength(2));
      expect(previousBloc.isClosed, isTrue);
      expect(blocs.last.isClosed, isFalse);
      expect(fields(tester).first.controller!.text, email);
      expect(fields(tester).last.controller!.text, password);
      expect(fields(tester).every((field) => field.enabled == true), isTrue);

      pending.completeError(AuthenticationException(errors: rejected));
      await tester.pumpAndSettle();

      expect(toast(tester).toast, isNull);
      expect(tester.takeException(), isNull);

      when(() => repository.signIn(email: email, password: password))
          .thenAnswer((_) async {});

      await submit(tester);
      await tester.pumpAndSettle();

      expect(fields(tester).every((field) => field.enabled == false), isTrue);
      verify(() => repository.signIn(email: email, password: password))
          .called(2);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'disposing during a pending ${fails ? 'failure' : 'success'} closes the bloc',
      (tester) async {
        final pending = holdRequest();
        await pumpScreen(tester);
        await fillForm(tester);
        await submit(tester);
        final bloc = blocs.single;

        await tester.pumpWidget(const SizedBox.shrink());
        expect(bloc.isClosed, isTrue);

        if (fails) {
          pending.completeError(AuthenticationException(errors: rejected));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SignInScreen), findsNothing);
      },
    );
  }
}
