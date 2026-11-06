import 'package:bloc/bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/observers/observer.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const signIn = SignInSubmittedEvent(
    email: 'private@example.test',
    password: 'fake-private-password',
  );
  late Talker talker;
  late SignInBloc bloc;
  late BlocObserver previousObserver;
  late AuthenticationRepositoryMock repository;

  setUp(() {
    previousObserver = Bloc.observer;
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    Bloc.observer = Observer(talker: talker);
    repository = AuthenticationRepositoryMock();
    when(
      () => repository.signIn(email: signIn.email, password: signIn.password),
    ).thenAnswer((_) async {});
    bloc = SignInBloc(repository: repository);
    talker.cleanHistory();
  });

  tearDown(() async {
    await bloc.close();
    Bloc.observer = previousObserver;
    talker.cleanHistory();
  });

  group('Debug Bloc logs', () {
    test('does not log password change credentials', () async {
      const event = ChangePasswordSubmitted(
        password: 'fixture-new-private',
        oldPassword: 'fixture-old-private',
        passwordConfirm: 'fixture-confirm-private',
      );
      when(
        () => repository.changePassword(
          password: event.password,
          oldPassword: event.oldPassword,
          passwordConfirm: event.passwordConfirm,
        ),
      ).thenAnswer((_) async {});
      when(repository.signOut).thenAnswer((_) async {});
      final change = ChangePasswordBloc(repository: repository);
      addTearDown(change.close);
      final changed = change.stream.firstWhere(
        (state) => state is ChangePasswordSuccess,
      );

      change.add(event);
      await changed;

      final messages = talker.history
          .map((log) => log.generateTextMessage())
          .join('\n');
      expect(messages, contains('ChangePasswordSubmitted'));
      expect(messages, isNot(contains('fixture-old-private')));
      expect(messages, isNot(contains('fixture-new-private')));
      expect(messages, isNot(contains('fixture-confirm-private')));
    });

    test('logs creation and closing to the supplied Talker', () async {
      final lifecycleBloc = SignInBloc(repository: repository);

      await lifecycleBloc.close();

      expect(talker.history.map((log) => log.message), [
        'SignInBloc created',
        'SignInBloc closed',
      ]);
    });

    test('logs event type without credentials', () async {
      final signedIn = bloc.stream.firstWhere(
        (state) => state is SignInSuccess,
      );

      bloc.add(signIn);
      await signedIn;

      final message = talker.history
          .whereType<BlocEventLog>()
          .single
          .generateTextMessage();
      expect(message, contains('SignInSubmittedEvent'));
      final messages = talker.history
          .map((log) => log.generateTextMessage())
          .join('\n');
      expect(messages, isNot(contains('private@example.test')));
      expect(messages, isNot(contains('fake-private-password')));
    });

    test('logs transition types without remote error details', () async {
      when(
        () => repository.signIn(email: signIn.email, password: signIn.password),
      ).thenThrow(
        AuthenticationException(
          errors: const ErrorsEntity(
            errors: [ErrorEntity(detail: 'fake-private-token')],
          ),
        ),
      );
      final failed = bloc.stream.firstWhere((state) => state is SignInFailure);

      bloc.add(signIn);
      await failed;

      final transitions = talker.history.whereType<BlocStateLog>();
      expect(transitions, hasLength(2));
      final message = transitions.last.generateTextMessage();
      expect(message, contains('SignInSubmitting'));
      expect(message, contains('SignInFailure'));
      final messages = talker.history
          .map((log) => log.generateTextMessage())
          .join('\n');
      expect(messages, isNot(contains('fake-private-token')));
      expect(messages, isNot(contains('fake-private-password')));
    });

    test('does not duplicate transitions through change logs', () async {
      final signedIn = bloc.stream.firstWhere(
        (state) => state is SignInSuccess,
      );

      bloc.add(signIn);
      await signedIn;

      expect(talker.history.whereType<BlocStateLog>(), hasLength(2));
      expect(talker.history.whereType<BlocChangeLog>(), isEmpty);
    });

    test(
      'logs unexpected error type and stack without its private message',
      () async {
        final stackTrace = StackTrace.current;
        when(
          () =>
              repository.signIn(email: signIn.email, password: signIn.password),
        ).thenAnswer(
          (_) =>
              Future<void>.error(StateError('fake-private-token'), stackTrace),
        );
        final failed = bloc.stream.firstWhere(
          (state) => state is SignInFailure,
        );

        bloc.add(signIn);
        await failed;

        final log = talker.history.singleWhere((log) => log.stackTrace != null);
        final message = log.generateTextMessage();
        expect(message, contains('SignInBloc'));
        expect(message, contains('StateError'));
        expect(log.stackTrace, same(stackTrace));
        expect(message, isNot(contains('fake-private-token')));
      },
    );
  });
}
