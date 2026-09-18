import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

final class AuthenticationRepository({
  required final IAuthenticationDataSource _dataSource,
}) implements IAuthenticationRepository {
  @override
  Future<Either<Failure, void>> checkSession() async {
    final hasSession = await _dataSource.checkSession();
    return hasSession ? const Right(null) : const Left(UnknownFailure());
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    final signedOut = await _dataSource.signOut();
    return signedOut ? const Right(null) : const Left(LogoutFailure());
  }

  @override
  Future<Either<Failure, void>> requestMagicLink({
    required String email,
  }) async {
    final accepted = await _dataSource.requestMagicLink(email: email);
    return accepted ? const Right(null) : const Left(MagicLinkRequestFailure());
  }

  @override
  Future<Either<Failure, void>> confirmCode({
    required String email,
    required String code,
  }) async {
    final accepted = await _dataSource.confirmCode(email: email, code: code);
    return accepted
        ? const Right(null)
        : const Left(MagicLinkConfirmationFailure());
  }
}
