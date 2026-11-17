abstract interface class ISessionRepository {
  Future<bool> loadSession();
  Stream<bool> get session;
}
