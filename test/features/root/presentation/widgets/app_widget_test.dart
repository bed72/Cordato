import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/screens/app/app_screen.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import '../../../../support/session/mocks/session_repository_mock.dart';

void main() {
  late SessionRepositoryMock repository;
  late StreamController<bool> changes;
  late List<SessionBloc> blocs;
  late List<Completer<bool>> reads;
  late GlobalKey<NavigatorState> navigatorKey;
  late ValueNotifier<SessionBloc Function()> factory;

  SessionBloc createBloc() {
    final bloc = SessionBloc(repository: repository);
    blocs.add(bloc);
    return bloc;
  }

  setUp(() {
    repository = SessionRepositoryMock();
    changes = StreamController<bool>.broadcast();
    blocs = [];
    reads = [];
    navigatorKey = GlobalKey<NavigatorState>();
    factory = ValueNotifier(createBloc);
    when(() => repository.sessionChanges).thenAnswer((_) => changes.stream);
  });

  Completer<bool> holdRead() {
    final pending = Completer<bool>();
    reads.add(pending);
    when(repository.loadSession).thenAnswer((_) => pending.future);
    return pending;
  }

  Future<void> pumpApp(WidgetTester tester, {String initialRoute = '/'}) async {
    final module = createModule(
      register: (context) {
        context.route('/', child: (_, _) => const AppScreen());
        for (final route in RouteEnum.values.where(
          (route) => route != RouteEnum.app,
        )) {
          context.route(
            route.path,
            child: (_, _) => Scaffold(body: Text('Route: ${route.path}')),
          );
        }
      },
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final pending in reads) {
        if (!pending.isCompleted) pending.complete(false);
      }
      unawaited(changes.close());
      await tester.pumpAndSettle();
      expect(changes.hasListener, isFalse);
      for (final bloc in blocs) {
        expect(bloc.isClosed, isTrue);
      }
      factory.dispose();
    });
    await tester.pumpWidget(
      ModularApp(
        module: module,
        navigatorKey: navigatorKey,
        initialRoute: initialRoute,
        child: ValueListenableBuilder<SessionBloc Function()>(
          valueListenable: factory,
          builder: (_, value, _) =>
              AppWidget(bloc: value, navigatorKey: navigatorKey),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('keeps the splash until the initial read finishes', (
    tester,
  ) async {
    final pending = holdRead();
    await pumpApp(tester);
    expect(find.byType(AppScreen), findsOneWidget);
    expect(changes.hasListener, isTrue);
    verify(repository.loadSession).called(1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Route: /welcome'), findsOneWidget);
    expect(find.byType(AppScreen), findsNothing);
    expect(blocs.single.isClosed, isFalse);
  });

  for (final present in [false, true]) {
    testWidgets('initial presence $present selects the corresponding entry', (
      tester,
    ) async {
      when(repository.loadSession).thenAnswer((_) async => present);
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(present ? 'Route: /dashboard' : 'Route: /welcome'),
        findsOneWidget,
      );
      expect(blocs, hasLength(1));
      verify(repository.loadSession).called(1);
      verify(() => repository.sessionChanges).called(1);
    });
  }

  testWidgets(
    'read failure falls back to welcome and a token event can recover',
    (tester) async {
      when(repository.loadSession)
          .thenAnswer((_) async => throw StateError('private storage failure'));
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('Route: /welcome'), findsOneWidget);
      expect(blocs.single.state, isA<SessionFailure>());
      expect(find.textContaining('private storage failure'), findsNothing);
      changes.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Route: /dashboard'), findsOneWidget);
    },
  );

  for (final entry in [RouteEnum.welcome, RouteEnum.authenticationSignIn]) {
    testWidgets(
      'token arrival on ${entry.path} redirects globally to dashboard',
      (tester) async {
        when(repository.loadSession).thenAnswer((_) async => false);
        await pumpApp(tester, initialRoute: entry.path);
        await tester.pumpAndSettle();
        expect(find.text('Route: ${entry.path}'), findsOneWidget);
        changes.add(true);
        await tester.pumpAndSettle();
        expect(find.text('Route: /dashboard'), findsOneWidget);
      },
    );
  }

  for (final route in RouteEnum.values.where((route) => route.authenticated)) {
    testWidgets('token loss on ${route.path} returns to welcome', (
      tester,
    ) async {
      when(repository.loadSession).thenAnswer((_) async => true);
      await pumpApp(tester);
      await tester.pumpAndSettle();
      tester.element(find.text('Route: /dashboard')).navigate(route.path);
      await tester.pumpAndSettle();
      expect(find.text('Route: ${route.path}'), findsOneWidget);
      changes.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Route: /welcome'), findsOneWidget);
      expect(blocs.single.isClosed, isFalse);
    });
  }

  for (final route in [
    RouteEnum.authenticationSignUp,
    RouteEnum.authenticationConfirm,
    RouteEnum.authenticationConfirmEmail,
  ]) {
    testWidgets('session events preserve public deep link ${route.path}', (
      tester,
    ) async {
      when(repository.loadSession).thenAnswer((_) async => false);
      await pumpApp(tester, initialRoute: route.path);
      await tester.pumpAndSettle();
      changes.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Route: ${route.path}'), findsOneWidget);
      changes.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Route: ${route.path}'), findsOneWidget);
    });
  }

  testWidgets(
    'a protected cold entry uses the splash until presence is known',
    (tester) async {
      final pending = holdRead();
      await pumpApp(tester, initialRoute: RouteEnum.settings.path);
      await tester.pumpAndSettle();
      expect(find.byType(AppScreen), findsOneWidget);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Route: /welcome'), findsOneWidget);
    },
  );

  testWidgets(
    'a protected cold entry still resolves through startup with a fast read',
    (tester) async {
      when(repository.loadSession).thenAnswer((_) async => true);
      await pumpApp(tester, initialRoute: RouteEnum.settings.path);
      await tester.pumpAndSettle();
      expect(find.text('Route: /dashboard'), findsOneWidget);
      expect(find.text('Route: /settings'), findsNothing);
    },
  );

  testWidgets(
    'a stale initial read cannot overwrite a token observed during startup',
    (tester) async {
      final pending = holdRead();
      await pumpApp(tester);
      changes.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Route: /dashboard'), findsOneWidget);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Route: /dashboard'), findsOneWidget);
    },
  );

  testWidgets('rebuild keeps the same owner, subscription and current route', (
    tester,
  ) async {
    when(repository.loadSession).thenAnswer((_) async => true);
    await pumpApp(tester);
    await tester.pumpAndSettle();
    final screen = tester.element(find.byType(AppWidget));
    screen.markNeedsBuild();
    await tester.pumpAndSettle();
    expect(find.text('Route: /dashboard'), findsOneWidget);
    expect(blocs, hasLength(1));
    verify(repository.loadSession).called(1);
    verify(() => repository.sessionChanges).called(1);
  });

  testWidgets(
    'factory replacement closes the old owner and ignores its late read',
    (tester) async {
      final previous = holdRead();
      await pumpApp(tester);
      final oldBloc = blocs.single;
      final next = holdRead();
      factory.value = () => createBloc();
      await tester.pump();
      await tester.pump();
      expect(oldBloc.isClosed, isTrue);
      expect(blocs, hasLength(2));
      previous.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(AppScreen), findsOneWidget);
      next.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Route: /welcome'), findsOneWidget);
      expect(blocs.last.isClosed, isFalse);
    },
  );

  testWidgets(
    'stream errors on a protected route fail safely and observation remains active',
    (tester) async {
      when(repository.loadSession).thenAnswer((_) async => true);
      await pumpApp(tester);
      await tester.pumpAndSettle();
      changes.addError(StateError('private watch failure'));
      await tester.pumpAndSettle();
      expect(find.text('Route: /welcome'), findsOneWidget);
      expect(changes.hasListener, isTrue);
      changes.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Route: /dashboard'), findsOneWidget);
    },
  );

  testWidgets(
    'dispose closes the application owner and ignores pending reads and navigation',
    (tester) async {
      final pending = holdRead();
      await pumpApp(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.completeError(StateError('late read failure'));
      changes.add(true);
      await tester.pumpAndSettle();
      expect(blocs.single.isClosed, isTrue);
      expect(changes.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
