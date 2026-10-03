import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/enums/email_verification_status_enum.dart';

typedef LogoutRepositoryType = Either<ErrorsEntity, bool>;
typedef SignUpRepositoryType = Either<ErrorsEntity, bool>;
typedef SignInRepositoryType = Either<ErrorsEntity, SessionEntity>;
typedef ResendEmailVerificationRepositoryType = Either<ErrorsEntity, bool>;

abstract interface class IAuthenticationRepository {
  Future<LogoutRepositoryType> logout();

  Future<EmailVerificationStatusEnum> confirmEmail(String url);

  Future<ResendEmailVerificationRepositoryType> resendEmailVerification({
    required String email,
  });

  Future<SignUpRepositoryType> signUp({
    required String email,
    required String password,
  });

  Future<SignInRepositoryType> signIn({
    required String email,
    required String password,
  });
}
