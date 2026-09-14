import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';

abstract interface class IAuthenticationRepository {
  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, void>> checkSession();

  Future<Either<Failure, void>> requestMagicLink({required String email});

  Future<Either<Failure, void>> confirmCode({
    required String code,
    required String email,
  });
}
