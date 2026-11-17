import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm_code/bloc/confirm_code_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm_code/bloc/confirm_code_event.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm_code/bloc/confirm_code_state.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = ConfirmCodeSubmittedEvent(
    userId: ' service-user ',
    code: ' 012345 ',
  );
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '401',
        code: 'user_invalid_token',
        pointer: '/secret',
        parameter: 'secret',
      ),
      ErrorEntity(status: '429', code: 'rate_limit_exceeded'),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<void> Function() answer) {
    when(
      () => repository.confirmCode(
        userId: submitted.userId,
        code: submitted.code,
      ),
    ).thenAnswer((_) => answer());
  }

  group('Initial state and confirmation', () {
    test('starts ready without confirming or requesting a code', () async {
      final bloc = ConfirmCodeBloc(repository: repository);
      addTearDown(bloc.close);

      expect(bloc.state, isA<ConfirmCodeInitial>());
      expect(bloc.state.canSubmit, isTrue);
      expect(bloc.state.isSubmitting, isFalse);
      verifyZeroInteractions(repository);
    });

    blocTest<ConfirmCodeBloc, ConfirmCodeState>(
      'delegates unchanged userId/code and completes without storing them in state',
      build: () {
        stub(() async {});
        return ConfirmCodeBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ConfirmCodeSubmitting>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
        isA<ConfirmCodeSuccess>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
      ],
      verify: (_) {
        verify(
          () => repository.confirmCode(
            userId: submitted.userId,
            code: submitted.code,
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Failures and manual retry', () {
    for (final failure in [errors, const ErrorsEntity(errors: [])]) {
      blocTest<ConfirmCodeBloc, ConfirmCodeState>(
        'preserves ${failure.errors.length} application errors without reporting or retrying',
        build: () {
          stub(() async => throw AuthenticationException(errors: failure));
          return ConfirmCodeBloc(repository: repository);
        },
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<ConfirmCodeSubmitting>(),
          isA<ConfirmCodeFailure>()
              .having((state) => state.errors, 'errors', same(failure))
              .having((state) => state.canSubmit, 'canSubmit', isTrue)
              .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
        ],
        errors: () => isEmpty,
        verify: (_) {
          verify(
            () => repository.confirmCode(
              userId: submitted.userId,
              code: submitted.code,
            ),
          ).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    blocTest<ConfirmCodeBloc, ConfirmCodeState>(
      'allows manual retry using a new userId and code after failure',
      build: () {
        stub(() async => throw AuthenticationException(errors: errors));
        when(() => repository.confirmCode(userId: 'new-user', code: '654321'))
            .thenAnswer((_) async {});
        return ConfirmCodeBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ConfirmCodeFailure,
        );
        bloc.add(submitted);
        await failed;
        bloc.add(
          const ConfirmCodeSubmittedEvent(userId: 'new-user', code: '654321'),
        );
      },
      expect: () => [
        isA<ConfirmCodeSubmitting>(),
        isA<ConfirmCodeFailure>(),
        isA<ConfirmCodeSubmitting>(),
        isA<ConfirmCodeSuccess>(),
      ],
      verify: (_) {
        verifyInOrder([
          () => repository.confirmCode(
            userId: submitted.userId,
            code: submitted.code,
          ),
          () => repository.confirmCode(userId: 'new-user', code: '654321'),
        ]);
        verifyNoMoreInteractions(repository);
      },
    );

    for (final unexpected in <Object>[
      StateError('private failure'),
      const FormatException('private payload'),
    ]) {
      blocTest<ConfirmCodeBloc, ConfirmCodeState>(
        'reports ${unexpected.runtimeType} with a safe retryable fallback',
        build: () {
          stub(() async => throw unexpected);
          return ConfirmCodeBloc(repository: repository);
        },
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<ConfirmCodeSubmitting>(),
          isA<ConfirmCodeFailure>()
              .having(
                (state) => state.errors.errors.single.title,
                'title',
                'Erro desconhecido',
              )
              .having(
                (state) => state.errors.errors.single.detail,
                'detail',
                'Não foi possível processar a resposta.',
              )
              .having((state) => state.canSubmit, 'canSubmit', isTrue),
        ],
        errors: () => [same(unexpected)],
      );
    }
  });

  group('Concurrency and lifecycle', () {
    test('dropped confirmations do not retry automatically after failure', () {
      fakeAsync((async) {
        final pending = Completer<void>();
        stub(() => pending.future);
        final bloc = ConfirmCodeBloc(repository: repository);
        bloc.add(submitted);
        async.flushMicrotasks();
        bloc.add(submitted);
        bloc.add(
          const ConfirmCodeSubmittedEvent(userId: 'other-user', code: '654321'),
        );
        async.flushMicrotasks();
        stub(() async {});
        pending.completeError(AuthenticationException(errors: errors));
        async.flushMicrotasks();

        expect(bloc.state, isA<ConfirmCodeFailure>());
        verify(
          () => repository.confirmCode(
            userId: submitted.userId,
            code: submitted.code,
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);
        bloc.add(submitted);
        async.flushMicrotasks();
        expect(bloc.state, isA<ConfirmCodeSuccess>());
        verify(
          () => repository.confirmCode(
            userId: submitted.userId,
            code: submitted.code,
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test(
      'awaits confirmation, drops pending submissions and blocks after success',
      () {
        fakeAsync((async) {
          final pending = Completer<void>();
          stub(() => pending.future);
          final bloc = ConfirmCodeBloc(repository: repository);
          final states = <ConfirmCodeState>[];
          final subscription = bloc.stream.listen(states.add);
          bloc.add(submitted);
          async.flushMicrotasks();
          bloc.add(submitted);
          bloc.add(
            const ConfirmCodeSubmittedEvent(
              userId: 'other-user',
              code: '654321',
            ),
          );
          async.flushMicrotasks();

          expect(bloc.state, isA<ConfirmCodeSubmitting>());
          verify(
            () => repository.confirmCode(
              userId: submitted.userId,
              code: submitted.code,
            ),
          ).called(1);
          pending.complete();
          async.flushMicrotasks();
          bloc.add(submitted);
          async.flushMicrotasks();

          expect(states, [
            isA<ConfirmCodeSubmitting>(),
            isA<ConfirmCodeSuccess>(),
          ]);
          verifyNoMoreInteractions(repository);
          unawaited(subscription.cancel());
          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      },
    );

    for (final outcome in [
      'success',
      'expected failure',
      'unexpected failure',
    ]) {
      test('closing during $outcome prevents late states', () async {
        final pending = Completer<void>();
        stub(() => pending.future);
        final bloc = ConfirmCodeBloc(repository: repository);
        addTearDown(bloc.close);
        final states = <ConfirmCodeState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final running = bloc.stream.firstWhere(
          (state) => state is ConfirmCodeSubmitting,
        );

        bloc.add(submitted);
        await running;
        final closing = bloc.close();
        switch (outcome) {
          case 'success':
            pending.complete();
          case 'expected failure':
            pending.completeError(AuthenticationException(errors: errors));
          default:
            pending.completeError(StateError('late failure'));
        }
        await closing;

        expect(bloc.isClosed, isTrue);
        expect(states, [isA<ConfirmCodeSubmitting>()]);
      });
    }

    test('keeps externally owned instances independent', () async {
      stub(() async {});
      final first = ConfirmCodeBloc(repository: repository);
      final second = ConfirmCodeBloc(repository: repository);
      addTearDown(first.close);
      addTearDown(second.close);
      final finished = first.stream.firstWhere(
        (state) => state is ConfirmCodeSuccess,
      );

      first.add(submitted);
      await finished;

      expect(second.state, isA<ConfirmCodeInitial>());
      verify(
        () => repository.confirmCode(
          userId: submitted.userId,
          code: submitted.code,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    });
  });
}
