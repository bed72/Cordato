import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';

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

final class AuthenticationRemoteDataSource({required final IHttpClient _client})
    implements IAuthenticationRemoteDataSource {
  @override
  Future<int?> confirmEmail(String url) async {
    try {
      final response = await _client.get(
        parameter: Requests(url, followRedirects: false, logRequest: false),
      );
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
    execute: () => _client.post(
      parameter: Requests.forPath(
        HttpPathEnum.signIn,
        body: {
          'data': {
            'type': 'access-tokens',
            'attributes': {'email': email, 'password': password},
          },
        },
      ),
    ),
  );

  @override
  Future<SignUpDataSourceType> signUp({
    required String email,
    required String password,
  }) => _response(
    fromJson: SignUpResponse.fromJson,
    execute: () => _client.post(
      parameter: Requests.forPath(
        HttpPathEnum.signUp,
        body: {
          'data': {
            'type': 'sign-ups',
            'attributes': {
              'email': email,
              'name': 'Trocado',
              'password': password,
              'password_confirmation': password,
            },
          },
        },
      ),
    ),
  );

  @override
  Future<ResendEmailVerificationDataSourceType> resendEmailVerification({
    required String email,
  }) => _response(
    fromJson: (_) => true,
    execute: () => _client.post(
      parameter: Requests.forPath(
        HttpPathEnum.resendEmailVerification,
        body: {
          'data': {
            'type': 'email-verifications',
            'attributes': {'email': email},
          },
        },
      ),
    ),
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
