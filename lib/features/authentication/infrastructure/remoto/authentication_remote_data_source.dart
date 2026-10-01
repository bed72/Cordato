import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';
import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';

typedef SignInDataSourceType = Either<ErrorsResponse, SignInResponse>;
typedef SignUpDataSourceType = Either<ErrorsResponse, SignUpResponse>;
typedef ResendEmailVerificationDataSourceType = Either<ErrorsResponse, bool>;

abstract interface class IAuthenticationRemoteDataSource {
  Future<int?> confirmEmail(String url);

  Future<ResendEmailVerificationDataSourceType> resendEmailVerification({
    required String email,
  });

  Future<SignUpDataSourceType> signUp({
    required String email,
    required String password,
  });

  Future<SignInDataSourceType> signIn({
    required String email,
    required String password,
  });
}

final class AuthenticationRemoteDataSource({
  required final IAuthenticationClient _client,
}) implements IAuthenticationRemoteDataSource {
  @override
  Future<int?> confirmEmail(String url) async {
    try {
      final response = await _client.confirmEmail(url);
      final status = response.fold(
        (failure) => failure.statusCode,
        (success) => success.statusCode,
      );
      return status == 0 ? null : status;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SignInDataSourceType> signIn({
    required String email,
    required String password,
  }) => _response(
    fromJson: SignInResponse.fromJson,
    execute: () => _client.signIn(email: email, password: password),
  );

  @override
  Future<SignUpDataSourceType> signUp({
    required String email,
    required String password,
  }) => _response(
    fromJson: SignUpResponse.fromJson,
    execute: () => _client.signUp(email: email, password: password),
  );

  @override
  Future<ResendEmailVerificationDataSourceType> resendEmailVerification({
    required String email,
  }) => _response(
    fromJson: (_) => true,
    execute: () => _client.resendEmailVerification(email: email),
  );

  Future<Either<ErrorsResponse, T>> _response<T>({
    required Future<Responses> Function() execute,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    late final Either<ErrorsResponse, T> data;

    try {
      final response = await execute();

      data = response.fold(
        (error) => Left(.fromJson(error.body)),
        (success) => Right(fromJson(success.body)),
      );
    } catch (_) {
      return Left(.unknown());
    }

    return data;
  }
}
