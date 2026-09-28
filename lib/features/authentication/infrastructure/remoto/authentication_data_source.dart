import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';

abstract interface class IAuthenticationDataSource {
  Future<Responses> signIn({required String email, required String password});

  Future<Responses> signUp({required String email, required String password});
}

final class AuthenticationDataSource({
  required final IAuthenticationClient _client,
}) implements IAuthenticationDataSource {
  @override
  Future<Responses> signIn({required String email, required String password}) {
    return _client.signIn(email: email, password: password);
  }

  @override
  Future<Responses> signUp({required String email, required String password}) {
    return _client.signUp(email: email, password: password);
  }
}
