abstract interface class IWidgetClient {
  Stream<Uri?> get launches;
  Stream<void> get monthlyRefreshRequests;

  int beginMonthlyRead();

  void requestMonthlyRefresh();

  Future<Uri?> initialLaunch();

  Future<void> setMonthlySessionActive({required bool active});

  Future<void> publishMonthlyTotal({
    required int cents,
    required int revision,
    required DateTime month,
  });
}
