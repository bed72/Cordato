import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

abstract interface class IAuthenticationClient {
  Future<bool> logout();

  Future<bool> checkSession();

  Future<bool> requestMagicLink({required String email});

  Future<bool> completeMagicLink({required String code});
}

final class SupabaseAuthenticationClient implements IAuthenticationClient {
  final String _redirectUrl;
  final SupabaseClient _client;

  SupabaseAuthenticationClient({
    required this._client,
    required this._redirectUrl,
  });

  @override
  Future<bool> checkSession() async => _client.auth.currentSession != null;

  @override
  Future<bool> requestMagicLink({required String email}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        emailRedirectTo: _redirectUrl,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> completeMagicLink({required String code}) async {
    try {
      await _client.auth.exchangeCodeForSession(code);

      return _client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await _client.auth.signOut();

      return true;
    } catch (_) {
      return false;
    }
  }
}
