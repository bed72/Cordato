import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/code/code_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/code/arguments/code_arguments.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/code/widgets/code_unavailable_widget.dart';

import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final authenticationModule = createModule(
  register: (context) => context
    ..addLazySingleton<IAuthenticationRepository>(AuthenticationRepository.new)
    ..add(EmailValidation.new)
    ..add(CodeValidation.new)
    ..route(
      RouteEnum.authenticationSignIn.path,
      provide: (scope) => scope.addBloc<SignInBloc>(SignInBloc.new),
      child: (context, _) => SignInScreen(
        bloc: context.read<SignInBloc>(),
        emailValidation: inject<EmailValidation>(),
      ),
    )
    ..route(
      RouteEnum.authenticationConfirm.path,
      provide: (scope) => scope
        ..addBloc<CodeBloc>(CodeBloc.new)
        ..addBloc<ResendEmailBloc>(ResendEmailBloc.new),
      child: (context, state) => switch (state.arguments) {
        CodeArguments(:final email, :final userId, isValid: true) => CodeScreen(
          email: email,
          userId: userId,
          codeBloc: context.read<CodeBloc>(),
          validation: inject<CodeValidation>(),
          resendBloc: context.read<ResendEmailBloc>(),
        ),
        _ => const CodeUnavailableWidget(),
      },
    ),
);
