import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';

import '../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  test('callback factories resolve the application contract without sibling routes', () async {
    final repository = AuthenticationRepositoryMock();
    when(() => repository.confirmEmail('verification-token'))
        .thenAnswer((_) async => EmailVerificationStatusEnum.success);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<IAuthenticationRepository>(repository)
          ..module(authenticationModule),
      ),
    );
    addTearDown(boot.injector.dispose);
    final first = boot.injector.get<CallbackBloc>();
    final second = boot.injector.get<CallbackBloc>();
    addTearDown(first.close);
    addTearDown(second.close);

    expect(first, isNot(same(second)));
    final finished = first.stream.firstWhere(
      (state) => state is CallbackSuccess,
    );
    first.add(const CallbackRequestedEvent(token: 'verification-token'));
    await finished;

    expect(second.state, isA<CallbackInitial>());
    verify(() => repository.confirmEmail('verification-token')).called(1);
  });
}
