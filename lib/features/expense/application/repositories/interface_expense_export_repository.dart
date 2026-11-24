import 'dart:typed_data';

abstract interface class IExpenseExportRepository {
  Future<Uint8List?> prepare();
}
