import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/callback_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/widgets/animated_ellipsis_widget.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const url = 'fixture.verification.token';
  const nextUrl = 'fixture.new.token';
  late AuthenticationRepositoryMock repository;
  late List<CallbackBloc> blocs;
  late List<Completer<EmailVerificationStatusEnum>> requests;
  late ValueNotifier<CallbackBloc Function()> factory;
  late ValueNotifier<String?> link;
  late RouterConfig<RouteState> router;

  CallbackBloc createBloc() {
    final bloc = CallbackBloc(repository: repository);
    blocs.add(bloc);
    return bloc;
  }

  setUp(() {
    repository = AuthenticationRepositoryMock();
    blocs = [];
    requests = [];
    factory = ValueNotifier(createBloc);
    link = ValueNotifier(url);
    router = modularRouterConfig(
      RouteCollection()
        ..add(
          ModularRoute(
            RouteEnum.authenticationConfirmEmail.path,
            (_, _) => ValueListenableBuilder<CallbackBloc Function()>(
              valueListenable: factory,
              builder: (_, value, _) => ValueListenableBuilder<String?>(
                valueListenable: link,
                builder: (_, address, _) =>
                    CallbackScreen(bloc: value, token: address),
              ),
            ),
          ),
        )
        ..add(
          ModularRoute(
            RouteEnum.welcome.path,
            (_, _) => const Scaffold(body: Text('Boas-vindas')),
          ),
        )
        ..add(
          ModularRoute(
            RouteEnum.authenticationSignIn.path,
            (_, _) => const Scaffold(body: Text('Tela de entrada')),
          ),
        ),
      initialRoute: RouteEnum.authenticationConfirmEmail.path,
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
        if (!pending.isCompleted) pending.complete(.success);
      }
      await tester.pumpAndSettle();
      for (final bloc in blocs) {
        expect(bloc.isClosed, isTrue);
      }
      factory.dispose();
      link.dispose();
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
    await tester.pump();
  }

  Completer<EmailVerificationStatusEnum> hold(String address) {
    final pending = Completer<EmailVerificationStatusEnum>();
    requests.add(pending);
    when(() => repository.confirmEmail(address))
        .thenAnswer((_) => pending.future);
    return pending;
  }

  testWidgets(
    'automatically confirms once and keeps accessible loading through rebuild',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final pending = hold(url);
      await pumpScreen(tester);
      await tester.pump();
      expect(find.byType(AnimatedEllipsisWidget), findsOneWidget);
      try {
        expect(find.bySemanticsLabel('Validando acesso...'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
      expect(find.text('Tela de entrada'), findsNothing);
      verify(() => repository.confirmEmail(url)).called(1);
      tester.element(find.byType(CallbackScreen)).markNeedsBuild();
      await tester.pump(const Duration(seconds: 2));
      expect(blocs, hasLength(1));
      verifyNoMoreInteractions(repository);
      pending.complete(.success);
      await tester.pumpAndSettle();
      expect(find.text('E-mail confirmado'), findsOneWidget);
      expect(find.text('Tela de entrada'), findsOneWidget);
      expect(blocs.single.isClosed, isTrue);
    },
  );

  for (final scenario in [
    (
      status: EmailVerificationStatusEnum.success,
      title: 'E-mail confirmado',
      description: 'Entre na sua conta para continuar.',
    ),
    (
      status: EmailVerificationStatusEnum.invalid,
      title: 'Link inválido ou expirado',
      description: 'Solicite um novo e-mail de confirmação.',
    ),
    (
      status: EmailVerificationStatusEnum.failure,
      title: 'Não foi possível confirmar o e-mail',
      description:
          'Verifique sua conexão e tente novamente com o link recebido.',
    ),
  ]) {
    testWidgets(
      '${scenario.status.name} shows one toast and resets navigation to welcome plus sign-in',
      (tester) async {
        when(() => repository.confirmEmail(url))
            .thenAnswer((_) async => scenario.status);
        await pumpScreen(tester);
        await tester.pumpAndSettle();
        expect(find.text(scenario.title), findsOneWidget);
        expect(find.text(scenario.description), findsOneWidget);
        expect(find.text('Tela de entrada'), findsOneWidget);
        expect(find.byType(CallbackScreen), findsNothing);
        final context = tester.element(find.text('Tela de entrada'));
        final notifier = ToastProviderWidget.of(context);
        final feedbackId = notifier.toast!.id;
        await tester.pump();
        expect(notifier.toast!.id, feedbackId);
        context.pop();
        await tester.pumpAndSettle();
        expect(find.text('Boas-vindas'), findsOneWidget);
        expect(find.byType(CallbackScreen), findsNothing);
        verify(() => repository.confirmEmail(url)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  for (final missing in <String?>[null, '']) {
    testWidgets(
      'missing link $missing navigates with invalid feedback without a request',
      (tester) async {
        link.value = missing;
        await pumpScreen(tester);
        await tester.pumpAndSettle();
        expect(find.text('Link inválido ou expirado'), findsOneWidget);
        expect(find.text('Tela de entrada'), findsOneWidget);
        verifyZeroInteractions(repository);
      },
    );
  }

  testWidgets('unexpected failures keep internal details out of the feedback', (
    tester,
  ) async {
    when(() => repository.confirmEmail(url))
        .thenAnswer((_) async => throw StateError('internal secret'));
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível confirmar o e-mail'), findsOneWidget);
    expect(find.textContaining('internal secret'), findsNothing);
    expect(find.text('Tela de entrada'), findsOneWidget);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'changing link ignores an obsolete ${fails ? 'error' : 'success'}',
      (tester) async {
        final previous = hold(url);
        final next = hold(nextUrl);
        await pumpScreen(tester);
        link.value = nextUrl;
        await tester.pump();
        await tester.pump();
        expect(blocs, hasLength(1));
        if (fails) {
          previous.completeError(StateError('obsolete error'));
        } else {
          previous.complete(.success);
        }
        await tester.pump();
        expect(find.text('Tela de entrada'), findsNothing);
        expect(find.text('E-mail confirmado'), findsNothing);
        next.complete(.invalid);
        await tester.pumpAndSettle();
        expect(find.text('Link inválido ou expirado'), findsOneWidget);
        expect(find.text('Tela de entrada'), findsOneWidget);
        verify(() => repository.confirmEmail(url)).called(1);
        verify(() => repository.confirmEmail(nextUrl)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  testWidgets(
    'replacing the factory closes its previous owner and confirms with the new bloc',
    (tester) async {
      final previous = hold(url);
      await pumpScreen(tester);
      final oldBloc = blocs.single;
      final next = hold(url);
      factory.value = () => createBloc();
      await tester.pump();
      await tester.pump();
      expect(oldBloc.isClosed, isTrue);
      expect(blocs, hasLength(2));
      previous.complete(.success);
      await tester.pump();
      expect(find.text('E-mail confirmado'), findsNothing);
      next.complete(.invalid);
      await tester.pumpAndSettle();
      expect(find.text('Link inválido ou expirado'), findsOneWidget);
      verify(() => repository.confirmEmail(url)).called(2);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'disposing ignores pending ${fails ? 'failure' : 'success'} and disposes animation',
      (tester) async {
        final pending = hold(url);
        await pumpScreen(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(blocs.single.isClosed, isTrue);
        if (fails) {
          pending.completeError(StateError('late error'));
        } else {
          pending.complete(.success);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AnimatedEllipsisWidget), findsNothing);
      },
    );
  }
}
