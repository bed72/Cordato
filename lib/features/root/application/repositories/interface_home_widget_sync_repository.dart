abstract interface class IHomeWidgetSyncRepository {
  Stream<void> get refreshRequests;

  Future<void> refresh();

  Future<void> setSessionActive({required bool active});
}
