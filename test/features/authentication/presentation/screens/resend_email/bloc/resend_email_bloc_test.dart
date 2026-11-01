import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = ResendEmailSubmittedEvent(email: ' Person@Example.com ');
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '429',
        title: 'Aguarde',
        detail: 'Tente novamente.',
        pointer: '/email',
        parameter: 'email',
      ),
      ErrorEntity(),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<void> Function() answer) {
    when(() => repository.resendEmail(email: any(named: 'email')))
        .thenAnswer((_) => answer());
  }

  group('Initial state and verification requests', () {
    test('starts ready without automatically resending', () async {
      final bloc = ResendEmailBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<ResendEmailInitial>());
      expect(bloc.state.canSubmit, isTrue);
      expect(bloc.state.isSubmitting, isFalse);
      verifyZeroInteractions(repository);
    });

    blocTest<ResendEmailBloc, ResendEmailState>(
      'delegates the email unchanged and accepts a later manual resend',
      build: () {
        stub(() async {});
        return ResendEmailBloc(repository: repository);
      },
      act: (bloc) async {
        final finished = bloc.stream.firstWhere(
          (state) => state is ResendEmailSuccess,
        );
        bloc.add(submitted);
        await finished;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResendEmailSubmitting>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
        isA<ResendEmailSuccess>()
            .having((state) => state.canSubmit, 'canSubmit', isTrue)
            .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailSuccess>(),
      ],
      verify: (_) {
        verify(() => repository.resendEmail(email: submitted.email)).called(2);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Failures and manual retry', () {
    for (final failure in [errors, const ErrorsEntity(errors: [])]) {
      blocTest<ResendEmailBloc, ResendEmailState>(
        'preserves ${failure.errors.length} application errors without reporting them',
        build: () {
          stub(() async => throw AuthenticationException(errors: failure));
          return ResendEmailBloc(repository: repository);
        },
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<ResendEmailSubmitting>(),
          isA<ResendEmailFailure>()
              .having((state) => state.errors, 'errors', same(failure))
              .having((state) => state.canSubmit, 'canSubmit', isTrue),
        ],
        errors: () => isEmpty,
      );
    }

    final unexpected = StateError('private failure');
    blocTest<ResendEmailBloc, ResendEmailState>(
      'reports unexpected failures and publishes a safe fallback',
      build: () {
        stub(() async => throw unexpected);
        return ResendEmailBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailFailure>()
            .having(
              (state) => state.errors.errors.single.title,
              'title',
              'Erro desconhecido',
            )
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
      errors: () => [same(unexpected)],
    );

    blocTest<ResendEmailBloc, ResendEmailState>(
      'allows manual retry after failure without reusing a previous success',
      build: () {
        var attempts = 0;
        stub(() async {
          if (++attempts == 2) throw AuthenticationException(errors: errors);
        });
        return ResendEmailBloc(repository: repository);
      },
      act: (bloc) async {
        final success = bloc.stream.firstWhere(
          (state) => state is ResendEmailSuccess,
        );
        bloc.add(submitted);
        await success;
        final failure = bloc.stream.firstWhere(
          (state) => state is ResendEmailFailure,
        );
        bloc.add(submitted);
        await failure;
        verify(() => repository.resendEmail(email: submitted.email)).called(2);
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailSuccess>(),
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailFailure>(),
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailSuccess>(),
      ],
      verify: (_) =>
          verify(() => repository.resendEmail(email: submitted.email))
              .called(1),
    );
  });

  group('Concurrency and lifecycle', () {
    test(
      'drops duplicate and different emails while pending instead of queueing',
      () async {
        final pending = Completer<void>();
        final started = Completer<void>();
        stub(() {
          started.complete();
          return pending.future;
        });
        final bloc = ResendEmailBloc(repository: repository);
        addTearDown(bloc.close);
        bloc.add(submitted);
        await started.future;
        bloc.add(submitted);
        bloc.add(const ResendEmailSubmittedEvent(email: 'other@example.com'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<ResendEmailSubmitting>());
        final finished = bloc.stream.firstWhere(
          (state) => state is ResendEmailSuccess,
        );
        pending.complete();
        await finished;
        await Future<void>.delayed(Duration.zero);
        verify(() => repository.resendEmail(email: submitted.email)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    for (final outcome in [
      'success',
      'expected failure',
      'unexpected failure',
    ]) {
      test('closing prevents late states for $outcome', () async {
        final pending = Completer<void>();
        final started = Completer<void>();
        stub(() {
          started.complete();
          return pending.future;
        });
        final bloc = ResendEmailBloc(repository: repository);
        final states = <ResendEmailState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);
        addTearDown(bloc.close);
        bloc.add(submitted);
        await started.future;
        final closing = bloc.close();
        switch (outcome) {
          case 'success':
            pending.complete();
          case 'expected failure':
            pending.completeError(AuthenticationException(errors: errors));
          default:
            pending.completeError(StateError('late error'));
        }
        await closing;
        expect(bloc.isClosed, isTrue);
        expect(states, [isA<ResendEmailSubmitting>()]);
      });
    }

    test('keeps screen-owned instances independent', () async {
      stub(() async {});
      final first = ResendEmailBloc(repository: repository);
      final second = ResendEmailBloc(repository: repository);
      addTearDown(first.close);
      addTearDown(second.close);
      final finished = first.stream.firstWhere(
        (state) => state is ResendEmailSuccess,
      );
      first.add(submitted);
      await finished;
      expect(second.state, isA<ResendEmailInitial>());
    });
  });
}
