import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';

typedef LogoutDataSourceType = Either<ErrorsResponse, bool>;
typedef ResendEmailDataSourceType = Either<ErrorsResponse, bool>;
typedef SignInDataSourceType = Either<ErrorsResponse, SignInResponse>;
typedef SignUpDataSourceType = Either<ErrorsResponse, SignUpResponse>;

abstract interface class IAuthenticationRemoteDataSource {
  Future<int?> confirmEmail(String url);

  Future<ResendEmailDataSourceType> resendEmail({required String email});

  Future<LogoutDataSourceType> logout();

  Future<SignUpDataSourceType> signUp({
    required String email,
    required String password,
    String? name,
    String? avatar,
  });

  Future<SignInDataSourceType> signIn({
    required String email,
    required String password,
  });
}

final class AuthenticationRemoteDataSource({required final IHttpClient _client})
    implements IAuthenticationRemoteDataSource {
  @override
  Future<LogoutDataSourceType> logout() => response(
    from: (_) => true,
    execute: () =>
        _client.delete(parameter: Requests(path: HttpPathEnum.logout.path)),
  );

  @override
  Future<ResendEmailDataSourceType> resendEmail({required String email}) =>
      response(
        from: (_) => true,
        execute: () => _client.post(
          parameter: Requests(
            path: HttpPathEnum.resendEmailVerification.path,
            body: {
              'data': {
                'type': 'email-verifications',
                'attributes': {'email': email},
              },
            },
          ),
        ),
      );

  @override
  Future<int?> confirmEmail(String url) async {
    final response = await _client.get(parameter: Requests(path: url));

    final status = response.fold(
      (failure) => failure.status,
      (success) => success.status,
    );

    return status == 0 ? null : status;
  }

  @override
  Future<SignInDataSourceType> signIn({
    required String email,
    required String password,
  }) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.post(
      parameter: Requests(
        path: HttpPathEnum.signIn.path,
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
    String? name,
    String? avatar,
  }) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.post(
      parameter: Requests(
        path: HttpPathEnum.signUp.path,
        body: {
          'data': {
            'type': 'sign-ups',
            'attributes': {
              'email': email,
              'avatar': ?avatar,
              'password': password,
              'name': name ?? 'Trocado',
              'password_confirmation': password,
            },
          },
        },
      ),
    ),
  );
}
