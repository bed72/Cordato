import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const url = 'https://other.example/confirm?signature=original&expires=123';
  const otherUrl = 'https://other.example/confirm?signature=new&expires=456';
  const requested = CallbackRequestedEvent(verificationUrl: url);
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  test('starts without confirming a link', () async {
    final bloc = CallbackBloc(repository: repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<CallbackInitial>());
    verifyZeroInteractions(repository);
  });

  for (final missing in <String?>[null, '']) {
    blocTest<CallbackBloc, CallbackState>(
      'rejects missing link $missing without calling the repository',
      build: () => CallbackBloc(repository: repository),
      act: (bloc) => bloc.add(CallbackRequestedEvent(verificationUrl: missing)),
      expect: () => [isA<CallbackConfirming>(), isA<CallbackInvalid>()],
      verify: (_) => verifyZeroInteractions(repository),
    );
  }

  for (final scenario in [
    (
      status: EmailVerificationStatusEnum.success,
      state: isA<CallbackSuccess>(),
    ),
    (
      status: EmailVerificationStatusEnum.invalid,
      state: isA<CallbackInvalid>(),
    ),
    (
      status: EmailVerificationStatusEnum.failure,
      state: isA<CallbackFailure>(),
    ),
  ]) {
    blocTest<CallbackBloc, CallbackState>(
      'maps ${scenario.status.name} and delegates the complete original URL',
      build: () {
        when(() => repository.confirmEmail(url))
            .thenAnswer((_) async => scenario.status);
        return CallbackBloc(repository: repository);
      },
      act: (bloc) => bloc.add(requested),
      expect: () => [isA<CallbackConfirming>(), scenario.state],
      errors: () => isEmpty,
      verify: (_) {
        verify(() => repository.confirmEmail(url)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  final unexpected = StateError('internal secret');
  blocTest<CallbackBloc, CallbackState>(
    'reports an unexpected error while exposing only a safe failure state',
    build: () {
      when(() => repository.confirmEmail(url))
          .thenAnswer((_) async => throw unexpected);
      return CallbackBloc(repository: repository);
    },
    act: (bloc) => bloc.add(requested),
    expect: () => [isA<CallbackConfirming>(), isA<CallbackFailure>()],
    errors: () => [same(unexpected)],
  );

  for (final fails in [false, true]) {
    test(
      'newest link wins over an obsolete ${fails ? 'error' : 'success'}',
      () async {
        final previous = Completer<EmailVerificationStatusEnum>();
        final next = Completer<EmailVerificationStatusEnum>();
        final started = Completer<void>();
        final nextStarted = Completer<void>();
        when(() => repository.confirmEmail(url)).thenAnswer((_) {
          started.complete();
          return previous.future;
        });
        when(() => repository.confirmEmail(otherUrl)).thenAnswer((_) {
          nextStarted.complete();
          return next.future;
        });
        final bloc = CallbackBloc(repository: repository);
        addTearDown(bloc.close);
        final states = <CallbackState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);
        bloc.add(requested);
        await started.future;
        bloc.add(const CallbackRequestedEvent(verificationUrl: otherUrl));
        await nextStarted.future;
        if (fails) {
          previous.completeError(StateError('obsolete error'));
        } else {
          previous.complete(.success);
        }
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<CallbackConfirming>());
        final finished = bloc.stream.firstWhere(
          (state) => state is CallbackInvalid,
        );
        next.complete(.invalid);
        await finished;
        expect(states.whereType<CallbackSuccess>(), isEmpty);
        expect(states.whereType<CallbackFailure>(), isEmpty);
        verify(() => repository.confirmEmail(url)).called(1);
        verify(() => repository.confirmEmail(otherUrl)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  test('an empty replacement invalidates a pending valid URL', () async {
    final pending = Completer<EmailVerificationStatusEnum>();
    final started = Completer<void>();
    when(() => repository.confirmEmail(url)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final bloc = CallbackBloc(repository: repository);
    addTearDown(bloc.close);
    bloc.add(requested);
    await started.future;
    final invalid = bloc.stream.firstWhere((state) => state is CallbackInvalid);
    bloc.add(const CallbackRequestedEvent(verificationUrl: null));
    await invalid;
    pending.complete(.success);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<CallbackInvalid>());
    verify(() => repository.confirmEmail(url)).called(1);
    verifyNoMoreInteractions(repository);
  });

  for (final fails in [false, true]) {
    test('closing ignores a pending ${fails ? 'error' : 'success'}', () async {
      final pending = Completer<EmailVerificationStatusEnum>();
      final started = Completer<void>();
      when(() => repository.confirmEmail(url)).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final bloc = CallbackBloc(repository: repository);
      addTearDown(bloc.close);
      final states = <CallbackState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      bloc.add(requested);
      await started.future;
      final closing = bloc.close();
      if (fails) {
        pending.completeError(StateError('late error'));
      } else {
        pending.complete(.success);
      }
      await closing;
      expect(bloc.isClosed, isTrue);
      expect(states, [isA<CallbackConfirming>()]);
    });
  }

  test('screen-owned instances remain independent', () async {
    when(() => repository.confirmEmail(url)).thenAnswer((_) async => .success);
    final first = CallbackBloc(repository: repository);
    final second = CallbackBloc(repository: repository);
    addTearDown(first.close);
    addTearDown(second.close);
    final finished = first.stream.firstWhere(
      (state) => state is CallbackSuccess,
    );
    first.add(requested);
    await finished;
    expect(second.state, isA<CallbackInitial>());
  });
}
