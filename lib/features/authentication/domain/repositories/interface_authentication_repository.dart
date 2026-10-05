import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';

typedef LogoutRepositoryType = Either<ErrorsEntity, bool>;
typedef SignUpRepositoryType = Either<ErrorsEntity, bool>;
typedef ResendEmailRepositoryType = Either<ErrorsEntity, bool>;
typedef SignInRepositoryType = Either<ErrorsEntity, SessionEntity>;

abstract interface class IAuthenticationRepository {
  Future<LogoutRepositoryType> logout();

  Future<SignUpRepositoryType> signUp({
    required String email,
    required String password,
  });

  Future<SignInRepositoryType> signIn({
    required String email,
    required String password,
  });

  Future<EmailVerificationStatusEnum> confirmEmail(String url);

  Future<ResendEmailRepositoryType> resendEmail({required String email});
}
