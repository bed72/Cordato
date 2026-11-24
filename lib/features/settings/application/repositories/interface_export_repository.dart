abstract interface class IExportRepository {
  Future<String?> prepare();
  Future<void> share({required String path});
  Future<void> discard({required String path});
}
