import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';
import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';

typedef SignInDataSourceResponse = Either<ErrorsResponse, SignInResponse>;
typedef SignUpDataSourceResponse = Either<ErrorsResponse, SignUpResponse>;

abstract interface class IAuthenticationDataSource {
  Future<SignInDataSourceResponse> signIn({
    required String email,
    required String password,
  });

  Future<SignUpDataSourceResponse> signUp({
    required String email,
    required String password,
  });
}

final class AuthenticationDataSource({
  required final IAuthenticationClient _client,
}) implements IAuthenticationDataSource {
  @override
  Future<SignInDataSourceResponse> signIn({
    required String email,
    required String password,
  }) => _response(
    fromJson: SignInResponse.fromJson,
    execute: () => _client.signIn(email: email, password: password),
  );

  @override
  Future<SignUpDataSourceResponse> signUp({
    required String email,
    required String password,
  }) => _response(
    fromJson: SignUpResponse.fromJson,
    execute: () => _client.signUp(email: email, password: password),
  );

  Future<Either<ErrorsResponse, T>> _response<T>({
    required Future<Responses> Function() execute,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    late final Either<ErrorsResponse, T> data;

    try {
      final response = await execute();

      data = response.fold(
        (error) => Left(.fromJson(error)),
        (success) => Right(fromJson(success)),
      );
    } catch (_) {
      return Left(.unknown());
    }

    return data;
  }
}
