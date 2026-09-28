import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_path.dart';

abstract interface class IAuthenticationClient {
  Future<Responses> signIn({required String email, required String password});

  Future<Responses> signUp({required String email, required String password});
}

final class AuthenticationClient({required final IHttpClient _client})
    implements IAuthenticationClient {
  @override
  Future<Responses> signIn({required String email, required String password}) =>
      _client.post(
        parameter: Requests(
          HttpPath.signIn.path,
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
        parameter: Requests(
          HttpPath.signUp.path,
          body: {
            'data': {
              'type': 'sign-ups',
              'attributes': {
                'email': email,
                'password': password,
                'name': email.split('@').first,
                'password_confirmation': password,
              },
            },
          },
        ),
      );
}
