import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/enums/email_verification_status_enum.dart';

abstract interface class IAuthenticationRepository {
  Future<EmailVerificationStatusEnum> confirm(String? verificationUrl);

  Future<Either<ErrorsEntity, SessionEntity>> signIn({
    required String email,
    required String password,
  });
  Future<Either<ErrorsEntity, bool>> signUp({
    required String email,
    required String password,
  });

  Future<Either<ErrorsEntity, bool>> resendEmailVerification({
    required String email,
  });
}
