abstract interface class ISessionClient {
  Stream<bool> get session;
  Future<void> close();
  Future<void> signOut();
  Future<bool> loadSession();
  Future<void> confirmCode({required String userId, required String code});
}
