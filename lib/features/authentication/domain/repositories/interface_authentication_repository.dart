abstract interface class IAuthenticationRepository {
  Future<bool> signIn({required String email, required String password});
  Future<bool> signUp({required String email, required String password});
}
