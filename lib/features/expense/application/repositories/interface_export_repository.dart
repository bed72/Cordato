import 'package:cordato/features/expense/application/models/document_model.dart';

abstract interface class IExportRepository {
  Future<DocumentModel?> prepare();

  void validateOwner(String ownerId);
}
