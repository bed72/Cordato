import 'package:supabase_flutter/supabase_flutter.dart'
    show OtpType, SupabaseClient;

abstract interface class IAuthenticationClient {
  Future<bool> signOut();

  Future<bool> checkSession();

  Future<bool> requestMagicLink({required String email});

  Future<bool> confirmCode({required String email, required String code});
}

final class SupabaseAuthenticationClient({
  required final String _redirectUrl,
  required final SupabaseClient _client,
}) implements IAuthenticationClient {
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
  Future<bool> confirmCode({
    required String code,
    required String email,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );

      return _client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      await _client.auth.signOut();

      return true;
    } catch (_) {
      return false;
    }
  }
}
