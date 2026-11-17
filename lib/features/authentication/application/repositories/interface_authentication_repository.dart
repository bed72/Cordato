abstract interface class IAuthenticationRepository {
  Future<void> signOut();
  Future<String> requestCode({required String email});
  Future<void> confirmCode({required String userId, required String code});
}
