abstract interface class IAuthenticationClient {
  Future<bool> signOut();

  Future<bool> checkSession();

  Future<bool> requestMagicLink({required String email});

  Future<bool> confirmCode({required String email, required String code});
}

final class SupabaseAuthenticationClient({required final String _redirectUrl})
    implements IAuthenticationClient {
  @override
  Future<bool> checkSession() async => false;

  @override
  Future<bool> requestMagicLink({required String email}) async {
    return false;
  }

  @override
  Future<bool> confirmCode({
    required String code,
    required String email,
  }) async {
    return false;
  }

  @override
  Future<bool> signOut() async {
    return false;
  }
}
