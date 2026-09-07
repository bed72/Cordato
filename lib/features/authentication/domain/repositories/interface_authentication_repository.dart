import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/core/domain/either.dart';

abstract interface class IAuthenticationRepository {
  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> checkSession();

  Future<Either<Failure, void>> requestMagicLink({required String email});

  Future<Either<Failure, void>> confirmCode({
    required String email,
    required String code,
  });
}
