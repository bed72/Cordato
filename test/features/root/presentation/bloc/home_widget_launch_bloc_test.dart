import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_state.dart';

import '../../../../support/root/mocks/home_widget_launch_repository_mock.dart';

void main() {
  late HomeWidgetLaunchRepositoryMock repository;
  late StreamController<void> launches;
  late Completer<void> subscribed;

  setUp(() {
    subscribed = Completer<void>();
    launches = StreamController<void>.broadcast(onListen: subscribed.complete);
    repository = HomeWidgetLaunchRepositoryMock();
    when(() => repository.expenseLaunches).thenAnswer((_) => launches.stream);
    when(repository.initialExpenseLaunch).thenAnswer((_) async => false);
  });

  tearDown(() => launches.close());

  test('starts without subscribing or reading native state', () async {
    final bloc = HomeWidgetLaunchBloc(repository: repository);

    expect(bloc.state, isA<HomeWidgetLaunchInitial>());
    expect(launches.hasListener, isFalse);
    verifyNever(repository.initialExpenseLaunch);

    await bloc.close();
  });

  blocTest<HomeWidgetLaunchBloc, HomeWidgetLaunchState>(
    'ordinary startup only begins listening',
    build: () => HomeWidgetLaunchBloc(repository: repository),
    act: (bloc) => bloc.add(const HomeWidgetLaunchStartedEvent()),
    expect: () => [isA<HomeWidgetLaunchListening>()],
  );

  blocTest<HomeWidgetLaunchBloc, HomeWidgetLaunchState>(
    'initial widget action becomes a presentation request without a URI',
    build: () {
      when(repository.initialExpenseLaunch).thenAnswer((_) async => true);
      return HomeWidgetLaunchBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const HomeWidgetLaunchStartedEvent()),
    expect: () => [
      isA<HomeWidgetLaunchListening>(),
      isA<HomeWidgetLaunchRequested>().having(
        (state) => state.sequence,
        'sequence',
        1,
      ),
    ],
  );

  blocTest<HomeWidgetLaunchBloc, HomeWidgetLaunchState>(
    'reports initial failures while retaining the observation',
    build: () {
      when(repository.initialExpenseLaunch)
          .thenThrow(StateError('initial native failure'));
      return HomeWidgetLaunchBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchFailure,
      );
      bloc.add(const HomeWidgetLaunchStartedEvent());
      await failed;
      final requested = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchRequested,
      );
      launches.add(null);
      await requested;
    },
    expect: () => [
      isA<HomeWidgetLaunchListening>(),
      isA<HomeWidgetLaunchFailure>(),
      isA<HomeWidgetLaunchRequested>(),
    ],
    errors: () => [isA<StateError>()],
  );

  test(
    'repeated starts keep one subscription and repeated taps remain distinct',
    () async {
      final bloc = HomeWidgetLaunchBloc(repository: repository);
      bloc.add(const HomeWidgetLaunchStartedEvent());
      await subscribed.future;
      bloc.add(const HomeWidgetLaunchStartedEvent());
      final first = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchRequested,
      );
      launches.add(null);
      await first;
      final second = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchRequested,
      );
      launches.add(null);

      final secondRequest = await second as HomeWidgetLaunchRequested;

      expect(secondRequest.sequence, 2);
      verify(() => repository.expenseLaunches).called(1);
      verify(repository.initialExpenseLaunch).called(1);
      await bloc.close();
      expect(launches.hasListener, isFalse);
    },
  );

  test(
    'a late initial snapshot does not duplicate an already observed launch',
    () async {
      final initial = Completer<bool>();
      when(repository.initialExpenseLaunch).thenAnswer((_) => initial.future);
      final bloc = HomeWidgetLaunchBloc(repository: repository);
      bloc.add(const HomeWidgetLaunchStartedEvent());
      await subscribed.future;
      final requested = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchRequested,
      );
      launches.add(null);
      await requested;

      initial.complete(true);
      await initial.future;

      expect((bloc.state as HomeWidgetLaunchRequested).sequence, 1);
      await bloc.close();
    },
  );

  test(
    'close cancels observation and ignores an initial read still pending',
    () async {
      final initial = Completer<bool>();
      when(repository.initialExpenseLaunch).thenAnswer((_) => initial.future);
      final bloc = HomeWidgetLaunchBloc(repository: repository);
      bloc.add(const HomeWidgetLaunchStartedEvent());
      await subscribed.future;

      final closing = bloc.close();
      initial.complete(true);
      await closing;

      expect(bloc.state, isA<HomeWidgetLaunchListening>());
      expect(launches.hasListener, isFalse);
    },
  );

  blocTest<HomeWidgetLaunchBloc, HomeWidgetLaunchState>(
    'stream failures are reported and the following launch can still be handled',
    build: () => HomeWidgetLaunchBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const HomeWidgetLaunchStartedEvent());
      await subscribed.future;
      final failed = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchFailure,
      );
      launches.addError(StateError('stream failure'));
      await failed;
      final requested = bloc.stream.firstWhere(
        (state) => state is HomeWidgetLaunchRequested,
      );
      launches.add(null);
      await requested;
    },
    expect: () => [
      isA<HomeWidgetLaunchListening>(),
      isA<HomeWidgetLaunchFailure>(),
      isA<HomeWidgetLaunchRequested>(),
    ],
    errors: () => [isA<StateError>()],
  );
}
