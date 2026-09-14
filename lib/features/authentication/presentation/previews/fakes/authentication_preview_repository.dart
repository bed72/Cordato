import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class AuthenticationPreviewRepository
    implements IAuthenticationRepository {
  const AuthenticationPreviewRepository();

  @override
  Future<Either<Failure, void>> checkSession() async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> confirmCode({
    required String email,
    required String code,
  }) async => const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> logout() async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> requestMagicLink({
    required String email,
  }) async => const Right<Failure, void>(null);
}
