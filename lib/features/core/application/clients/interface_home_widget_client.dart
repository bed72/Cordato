abstract interface class IHomeWidgetClient {
  Stream<Uri?> get launches;

  Future<Uri?> initialLaunch();
}
