abstract interface class IHomeWidgetSyncRepository {
  Future<void> enable();
  Future<void> refresh();
  Stream<void> get refreshRequests;
}
