import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';

abstract interface class IAuthenticationDataSource {
  Future<bool> signOut();

  Future<bool> checkSession();

  Future<bool> requestMagicLink({required String email});

  Future<bool> confirmCode({required String email, required String code});
}

final class AuthenticationDataSource({
  required final IAuthenticationClient _client,
}) implements IAuthenticationDataSource {
  @override
  Future<bool> signOut() => _client.signOut();

  @override
  Future<bool> checkSession() => _client.checkSession();

  @override
  Future<bool> requestMagicLink({required String email}) =>
      _client.requestMagicLink(email: email);

  @override
  Future<bool> confirmCode({required String email, required String code}) =>
      _client.confirmCode(email: email, code: code);
}
