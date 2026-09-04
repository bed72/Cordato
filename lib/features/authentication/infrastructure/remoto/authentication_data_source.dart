import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';

abstract interface class IAuthenticationDataSource {
  Future<bool> logout();

  Future<bool> checkSession();

  Future<bool> requestMagicLink({required String email});

  Future<bool> completeMagicLink({required String code});
}

final class AuthenticationDataSource implements IAuthenticationDataSource {
  final IAuthenticationClient _client;

  AuthenticationDataSource({required this._client});

  @override
  Future<bool> logout() => _client.logout();

  @override
  Future<bool> checkSession() => _client.checkSession();

  @override
  Future<bool> requestMagicLink({required String email}) =>
      _client.requestMagicLink(email: email);

  @override
  Future<bool> completeMagicLink({required String code}) =>
      _client.completeMagicLink(code: code);
}
