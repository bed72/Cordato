import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/core/domain/either.dart';

final class LogoutPreviewRepository implements IAuthenticationRepository {
  const LogoutPreviewRepository();

  @override
  Future<Either<Failure, void>> checkSession() async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> confirmCode({
    required String email,
    required String code,
  }) async => const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> signOut() async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> requestMagicLink({
    required String email,
  }) async => const Right<Failure, void>(null);
}
