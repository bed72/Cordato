import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/local/authentication_local_data_source.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_remote_data_source.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({
  required final IAuthenticationLocalDataSource _localDataSource,
  required final IAuthenticationRemoteDataSource _remoteDataSource,
}) implements IAuthenticationRepository {
  @override
  Future<LogoutRepositoryType> logout() async {
    try {
      final data = await _remoteDataSource.logout();

      if (data case Left(:final value)) return Left(value.toEntity());
      if (!data.right) return const Right(false);

      await _localDataSource.remove();

      return const Right(true);
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<EmailVerificationStatusEnum> confirmEmail(String url) async {
    if (url.isEmpty) return .invalid;

    try {
      final status = await _remoteDataSource.confirmEmail(url);

      return switch (status) {
        204 => .success,
        403 => .invalid,
        _ => .failure,
      };
    } catch (_) {
      return .failure;
    }
  }

  @override
  Future<ResendEmailRepositoryType> resendEmail({required String email}) async {
    try {
      final data = await _remoteDataSource.resendEmail(email: email);
      return data.either((errors) => errors.toEntity(), (success) => success);
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<SignUpRepositoryType> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _remoteDataSource.signUp(
        email: email,
        password: password,
      );

      return data.either((errors) => errors.toEntity(), (_) => true);
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<SignInRepositoryType> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _remoteDataSource.signIn(
        email: email,
        password: password,
      );

      if (data case Left(:final value)) return Left(value.toEntity());

      final session = data.right.toEntity();
      await _localDataSource.save(session.token);
      return Right(session);
    } catch (_) {
      return Left(.unknown());
    }
  }
}
