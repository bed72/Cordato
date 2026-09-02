import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/core/domain/either.dart';

final class AuthenticationRepository implements IAuthenticationRepository {
  final IAuthenticationDataSource _dataSource;

  AuthenticationRepository({required this._dataSource});

  @override
  Future<Either<Failure, void>> checkSession() async {
    final hasSession = await _dataSource.checkSession();
    return hasSession ? const Right(null) : const Left(UnknownFailure());
  }

  @override
  Future<Either<Failure, void>> logout() async {
    final signedOut = await _dataSource.logout();
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
  Future<Either<Failure, void>> completeMagicLink({
    required String code,
    String? flowId,
  }) async {
    final accepted = await _dataSource.completeMagicLink(code: code);
    return accepted
        ? const Right(null)
        : const Left(MagicLinkConfirmationFailure());
  }
}
