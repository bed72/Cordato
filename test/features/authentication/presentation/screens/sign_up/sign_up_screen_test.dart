import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const email = 'Person@Example.com';
  const password = 'Teste1';
  const rejected = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '409',
        pointer: '/data/attributes/email',
        detail: 'E-mail já cadastrado.',
      ),
      ErrorEntity(
        status: '422',
        pointer: '/data/attributes/password',
        detail: 'Senha rejeitada.',
      ),
      ErrorEntity(title: 'Cadastro indisponível', detail: 'Tente mais tarde.'),
    ],
  );
  late AuthenticationRepositoryMock repository;
  late List<SignUpBloc> blocs;
  late List<Completer<void>> requests;
  late ValueNotifier<SignUpBloc Function()> factory;
  late RouterConfig<RouteState> router;
  late int confirmations;
  late Object? confirmedEmail;

  SignUpBloc createBloc() {
    final bloc = SignUpBloc(repository: repository);
    blocs.add(bloc);
    return bloc;
  }

  setUp(() {
    repository = AuthenticationRepositoryMock();
    blocs = [];
    requests = [];
    confirmations = 0;
    confirmedEmail = null;
    factory = ValueNotifier(createBloc);
    router = modularRouterConfig(
      RouteCollection()
        ..add(
          ModularRoute(
            RouteEnum.authenticationSignUp.path,
            (_, _) => ValueListenableBuilder<SignUpBloc Function()>(
              valueListenable: factory,
              builder: (_, value, _) => SignUpScreen(
                bloc: value,
                emailValidation: const EmailValidation(),
                passwordValidation: const PasswordValidation(),
              ),
            ),
          ),
        )
        ..add(
          ModularRoute(RouteEnum.authenticationConfirm.path, (_, state) {
            confirmations++;
            confirmedEmail = state.arguments;
            return const Scaffold(body: Text('Confirme seu e-mail'));
          }),
        )
        ..add(
          ModularRoute(
            RouteEnum.authenticationSignIn.path,
            (_, _) => const Scaffold(body: Text('Tela de entrada')),
          ),
        ),
      initialRoute: RouteEnum.authenticationSignUp.path,
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
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
      factory.dispose();
      (router.routerDelegate as ChangeNotifier).dispose();
      (router.routeInformationProvider as PlatformRouteInformationProvider)
          .dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        theme: Themes.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (_, child) => ToastProviderWidget(child: child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String address = email,
    String secret = password,
  }) async {
    await tester.enterText(find.byType(TextField).first, address);
    await tester.enterText(find.byType(TextField).last, secret);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  void stub(Future<void> Function() answer) {
    when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  Completer<void> hold() {
    final pending = Completer<void>();
    requests.add(pending);
    stub(() => pending.future);
    return pending;
  }

  List<TextField> fields(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).toList();

  testWidgets(
    'initial form validates locally and clears only the edited error',
    (tester) async {
      await pumpScreen(tester);
      expect(find.text('Vamos lá'), findsOneWidget);
      expect(find.text('Criar conta'), findsOneWidget);
      expect(fields(tester).last.obscureText, isTrue);
      await submit(tester);
      expect(find.text('E-mail obrigatório'), findsOneWidget);
      expect(find.text('Senha obrigatória'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'invalid');
      await tester.pump();
      expect(find.text('E-mail obrigatório'), findsNothing);
      expect(find.text('Senha obrigatória'), findsOneWidget);
      await submit(tester);
      expect(find.text('E-mail inválido'), findsOneWidget);
      verifyZeroInteractions(repository);
    },
  );

  testWidgets(
    'trims email, preserves password, blocks duplicate sends and confirms once',
    (tester) async {
      final pending = hold();
      await pumpScreen(tester);
      await fill(tester, address: ' $email ', secret: ' $password ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await submit(tester);
      expect(fields(tester).every((field) => field.enabled == false), isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      verify(() => repository.signUp(email: email, password: ' $password '))
          .called(1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Confirme seu e-mail'), findsOneWidget);
      expect(confirmedEmail, email);
      expect(confirmations, 1);
      await tester.pumpAndSettle();
      expect(confirmations, 1);
      expect(find.byType(SignUpScreen), findsNothing);
      expect(blocs.single.isClosed, isTrue);
      verifyNoMoreInteractions(repository);
    },
  );

  testWidgets(
    'preserves 409/422 field errors, remaining toast and manual retry',
    (tester) async {
      stub(() async => throw AuthenticationException(errors: rejected));
      await pumpScreen(tester);
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('E-mail já cadastrado.'), findsOneWidget);
      expect(find.text('Senha rejeitada.'), findsOneWidget);
      expect(find.text('Tente mais tarde.'), findsOneWidget);
      expect(fields(tester).first.controller!.text, email);
      expect(fields(tester).last.controller!.text, password);
      final notifier = ToastProviderWidget.of(
        tester.element(find.byType(SignUpScreen)),
      );
      final toastId = notifier.toast!.id;
      tester.element(find.byType(SignUpScreen)).markNeedsBuild();
      await tester.pumpAndSettle();
      expect(blocs, hasLength(1));
      expect(notifier.toast!.id, toastId);
      verify(() => repository.signUp(email: email, password: password))
          .called(1);
      await tester.enterText(find.byType(TextField).first, 'other@example.com');
      await tester.pump();
      expect(find.text('E-mail já cadastrado.'), findsNothing);
      expect(find.text('Senha rejeitada.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, email);
      stub(() async {});
      await submit(tester);
      await tester.pumpAndSettle();
      expect(confirmedEmail, email);
      verify(() => repository.signUp(email: email, password: password))
          .called(1);
    },
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(errors: [ErrorEntity()]),
  ]) {
    testWidgets(
      'empty or incomplete errors use safe feedback: ${errors.errors.length}',
      (tester) async {
        stub(() async => throw AuthenticationException(errors: errors));
        await pumpScreen(tester);
        await fill(tester);
        await submit(tester);
        await tester.pumpAndSettle();
        expect(find.text('Erro ao criar conta'), findsOneWidget);
        expect(
          find.text('Não foi possível criar sua conta. Tente novamente.'),
          findsOneWidget,
        );
        expect(fields(tester).every((field) => field.enabled == true), isTrue);
        expect(confirmations, 0);
      },
    );
  }

  testWidgets('unexpected failures do not expose internal details', (
    tester,
  ) async {
    stub(() async => throw StateError('internal secret'));
    await pumpScreen(tester);
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Erro desconhecido'), findsOneWidget);
    expect(find.textContaining('internal secret'), findsNothing);
    expect(fields(tester).every((field) => field.enabled == true), isTrue);
    expect(confirmations, 0);
  });

  testWidgets(
    'factory replacement closes the old bloc and ignores its late success',
    (tester) async {
      final pending = hold();
      await pumpScreen(tester);
      await fill(tester);
      await submit(tester);
      final previous = blocs.single;
      factory.value = () => createBloc();
      await tester.pump();
      expect(previous.isClosed, isTrue);
      expect(blocs, hasLength(2));
      expect(fields(tester).first.controller!.text, email);
      expect(fields(tester).every((field) => field.enabled == true), isTrue);
      pending.complete();
      await tester.pumpAndSettle();
      expect(confirmations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets('leaving ignores pending ${fails ? 'failure' : 'success'}', (
      tester,
    ) async {
      final pending = hold();
      await pumpScreen(tester);
      await fill(tester);
      await submit(tester);
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Tela de entrada'), findsOneWidget);
      expect(blocs.single.isClosed, isTrue);
      if (fails) {
        pending.completeError(AuthenticationException(errors: rejected));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(confirmations, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
