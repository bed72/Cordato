import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

abstract interface class IAuthenticationClient {
  Future<Responses> confirmEmail(String url);

  Future<Responses> resendEmailVerification({required String email});

  Future<Responses> signIn({required String email, required String password});

  Future<Responses> signUp({required String email, required String password});
}

final class AuthenticationClient({required final IHttpClient _client})
    implements IAuthenticationClient {
  @override
  Future<Responses> confirmEmail(String url) => _client.get(
    parameter: Requests(url, followRedirects: false, logRequest: false),
  );

  @override
  Future<Responses> signIn({required String email, required String password}) =>
      _client.post(
        parameter: Requests.forPath(
          HttpPathEnum.signIn,
          body: {
            'data': {
              'type': 'access-tokens',
              'attributes': {'email': email, 'password': password},
            },
          },
        ),
      );

  @override
  Future<Responses> signUp({required String email, required String password}) =>
      _client.post(
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
      );

  @override
  Future<Responses> resendEmailVerification({required String email}) =>
      _client.post(
        parameter: Requests.forPath(
          HttpPathEnum.resendEmailVerification,
          body: {
            'data': {
              'type': 'email-verifications',
              'attributes': {'email': email},
            },
          },
        ),
      );
}
