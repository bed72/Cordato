import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/root/presentation/bloc/widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_state.dart';

import '../../../../support/root/mocks/widget_launch_repository_mock.dart';

void main() {
  late WidgetLaunchRepositoryMock repository;
  late StreamController<void> launches;
  late Completer<void> subscribed;

  setUp(() {
    subscribed = Completer<void>();
    launches = StreamController<void>.broadcast(onListen: subscribed.complete);
    repository = WidgetLaunchRepositoryMock();
    when(() => repository.expenseLaunches).thenAnswer((_) => launches.stream);
    when(repository.initialExpenseLaunch).thenAnswer((_) async => false);
  });

  tearDown(() => launches.close());

  test('starts without subscribing or reading native state', () async {
    final bloc = WidgetLaunchBloc(repository: repository);

    expect(bloc.state, isA<WidgetLaunchInitial>());
    expect(launches.hasListener, isFalse);
    verifyNever(repository.initialExpenseLaunch);

    await bloc.close();
  });

  blocTest<WidgetLaunchBloc, WidgetLaunchState>(
    'ordinary startup only begins listening',
    build: () => WidgetLaunchBloc(repository: repository),
    act: (bloc) => bloc.add(const WidgetLaunchStartedEvent()),
    expect: () => [isA<WidgetLaunchListening>()],
  );

  blocTest<WidgetLaunchBloc, WidgetLaunchState>(
    'initial widget action becomes a presentation request without a URI',
    build: () {
      when(repository.initialExpenseLaunch).thenAnswer((_) async => true);
      return WidgetLaunchBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const WidgetLaunchStartedEvent()),
    expect: () => [
      isA<WidgetLaunchListening>(),
      isA<WidgetLaunchRequested>().having(
        (state) => state.sequence,
        'sequence',
        1,
      ),
    ],
  );

  blocTest<WidgetLaunchBloc, WidgetLaunchState>(
    'reports initial failures while retaining the observation',
    build: () {
      when(repository.initialExpenseLaunch)
          .thenThrow(StateError('initial native failure'));
      return WidgetLaunchBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchFailure,
      );
      bloc.add(const WidgetLaunchStartedEvent());
      await failed;
      final requested = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchRequested,
      );
      launches.add(null);
      await requested;
    },
    expect: () => [
      isA<WidgetLaunchListening>(),
      isA<WidgetLaunchFailure>(),
      isA<WidgetLaunchRequested>(),
    ],
    errors: () => [isA<StateError>()],
  );

  test(
    'repeated starts keep one subscription and repeated taps remain distinct',
    () async {
      final bloc = WidgetLaunchBloc(repository: repository);
      bloc.add(const WidgetLaunchStartedEvent());
      await subscribed.future;
      bloc.add(const WidgetLaunchStartedEvent());
      final first = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchRequested,
      );
      launches.add(null);
      await first;
      final second = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchRequested,
      );
      launches.add(null);

      final secondRequest = await second as WidgetLaunchRequested;

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
      final bloc = WidgetLaunchBloc(repository: repository);
      bloc.add(const WidgetLaunchStartedEvent());
      await subscribed.future;
      final requested = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchRequested,
      );
      launches.add(null);
      await requested;

      initial.complete(true);
      await initial.future;

      expect((bloc.state as WidgetLaunchRequested).sequence, 1);
      await bloc.close();
    },
  );

  test(
    'close cancels observation and ignores an initial read still pending',
    () async {
      final initial = Completer<bool>();
      when(repository.initialExpenseLaunch).thenAnswer((_) => initial.future);
      final bloc = WidgetLaunchBloc(repository: repository);
      bloc.add(const WidgetLaunchStartedEvent());
      await subscribed.future;

      final closing = bloc.close();
      initial.complete(true);
      await closing;

      expect(bloc.state, isA<WidgetLaunchListening>());
      expect(launches.hasListener, isFalse);
    },
  );

  blocTest<WidgetLaunchBloc, WidgetLaunchState>(
    'stream failures are reported and the following launch can still be handled',
    build: () => WidgetLaunchBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const WidgetLaunchStartedEvent());
      await subscribed.future;
      final failed = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchFailure,
      );
      launches.addError(StateError('stream failure'));
      await failed;
      final requested = bloc.stream.firstWhere(
        (state) => state is WidgetLaunchRequested,
      );
      launches.add(null);
      await requested;
    },
    expect: () => [
      isA<WidgetLaunchListening>(),
      isA<WidgetLaunchFailure>(),
      isA<WidgetLaunchRequested>(),
    ],
    errors: () => [isA<StateError>()],
  );
}
