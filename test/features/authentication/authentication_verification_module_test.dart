import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';

import '../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  test(
    'verification retry after account creation never recreates the account',
    () async {
      final repository = AuthenticationRepositoryMock();
      when(
        () => repository.signUp(
          email: 'person@example.com',
          password: 'Example1',
        ),
      ).thenAnswer((_) async {});
      when(() => repository.resendEmail(email: 'person@example.com'))
          .thenThrow(AuthenticationException(errors: ErrorsEntity.unknown()));
      final boot = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<IAuthenticationRepository>(repository)
            ..module(authenticationModule),
        ),
      );
      addTearDown(boot.injector.dispose);
      final signUp = boot.injector.get<SignUpBloc>();
      final verification = boot.injector.get<ResendEmailBloc>();
      addTearDown(signUp.close);
      addTearDown(verification.close);

      final created = signUp.stream.firstWhere(
        (state) => state is SignUpSuccess,
      );
      signUp.add(
        const SignUpSubmittedEvent(
          email: 'person@example.com',
          password: 'Example1',
        ),
      );
      final account = await created as SignUpSuccess;

      final failed = verification.stream.firstWhere(
        (state) => state is ResendEmailFailure,
      );
      verification.add(ResendEmailStartedEvent(email: account.email));
      final failure = await failed as ResendEmailFailure;
      expect(failure.isInitialRequest, isTrue);
      expect(failure.canSubmit, isTrue);
      expect(failure.remaining, Duration.zero);
      expect(signUp.state, same(account));
      expect(signUp.state.canSubmit, isFalse);

      final sent = verification.stream.firstWhere(
        (state) => state is ResendEmailSuccess,
      );
      when(() => repository.resendEmail(email: account.email))
          .thenAnswer((_) async {});
      verification.add(ResendEmailSubmittedEvent(email: account.email));
      await sent;

      expect(verification.state.canSubmit, isFalse);
      expect(verification.state.remaining, const Duration(seconds: 60));
      verify(
        () => repository.signUp(email: account.email, password: 'Example1'),
      ).called(1);
      verify(() => repository.resendEmail(email: account.email)).called(2);
    },
  );
}
