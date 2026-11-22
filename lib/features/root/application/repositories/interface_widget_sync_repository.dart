abstract interface class IWidgetSyncRepository {
  Future<void> enable();
  Future<void> refresh();
  Stream<void> get refreshRequests;
}
