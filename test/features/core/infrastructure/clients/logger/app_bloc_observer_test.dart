import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';
import 'package:cordato/features/core/infrastructure/clients/logger/app_bloc_observer.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';

import '../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  late Talker talker;
  late AppBlocObserver observer;
  late SignInBloc bloc;

  setUp(() {
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    observer = AppBlocObserver(talker: talker);
    bloc = SignInBloc(repository: AuthenticationRepositoryMock());
  });

  tearDown(() async {
    await bloc.close();
    talker.cleanHistory();
  });

  group('Debug Bloc logs', () {
    test('does not log password change credentials', () async {
      final change = ChangePasswordBloc(
        repository: AuthenticationRepositoryMock(),
      );
      addTearDown(change.close);
      observer.onEvent(
        change,
        const ChangePasswordSubmitted(
          oldPassword: 'fixture-old-private',
          password: 'fixture-new-private',
          passwordConfirm: 'fixture-confirm-private',
        ),
      );
      final message = talker.history.single.generateTextMessage();
      expect(message, contains('ChangePasswordSubmitted'));
      expect(message, isNot(contains('fixture-old-private')));
      expect(message, isNot(contains('fixture-new-private')));
      expect(message, isNot(contains('fixture-confirm-private')));
    });
    test('logs creation and closing to the supplied Talker', () {
      observer.onCreate(bloc);
      observer.onClose(bloc);

      expect(talker.history.map((log) => log.message), [
        'SignInBloc created',
        'SignInBloc closed',
      ]);
    });

    test('logs event type without credentials', () {
      observer.onEvent(
        bloc,
        const SignInSubmittedEvent(
          email: 'private@example.test',
          password: 'fake-private-password',
        ),
      );

      final message = talker.history.single.generateTextMessage();
      expect(message, contains('SignInSubmittedEvent'));
      expect(message, isNot(contains('private@example.test')));
      expect(message, isNot(contains('fake-private-password')));
      expect(observer.settings.printEventFullData, isFalse);
    });

    test('logs transition types without remote error details', () {
      observer.onTransition(
        bloc,
        Transition<SignInEvent, SignInState>(
          currentState: const SignInSubmitting(),
          event: const SignInSubmittedEvent(
            email: 'private@example.test',
            password: 'fake-private-password',
          ),
          nextState: const SignInFailure(
            errors: ErrorsEntity(
              errors: [ErrorEntity(detail: 'fake-private-token')],
            ),
          ),
        ),
      );

      final message = talker.history.single.generateTextMessage();
      expect(message, contains('SignInSubmitting'));
      expect(message, contains('SignInFailure'));
      expect(message, isNot(contains('fake-private-token')));
      expect(message, isNot(contains('fake-private-password')));
      expect(observer.settings.printStateFullData, isFalse);
    });

    test('does not duplicate transitions through change logs', () {
      observer.onChange(
        bloc,
        const Change<SignInState>(
          currentState: SignInInitial(),
          nextState: SignInSubmitting(),
        ),
      );

      expect(talker.history, isEmpty);
    });

    test(
      'logs unexpected error type and stack without its private message',
      () {
        final stackTrace = StackTrace.current;
        observer.onError(bloc, StateError('fake-private-token'), stackTrace);

        final log = talker.history.single;
        final message = log.generateTextMessage();
        expect(message, contains('SignInBloc'));
        expect(message, contains('StateError'));
        expect(message, isNot(contains('fake-private-token')));
        expect(log.stackTrace, same(stackTrace));
      },
    );
  });
}
