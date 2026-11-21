import 'package:cordato/features/core/application/enums/share_outcome_enum.dart';
import 'package:cordato/features/core/application/models/share_origin_model.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/core/application/exceptions/file_share_exception.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/models/prepared_export_model.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';
import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart'
    as expense;

final class ExportRepository({
  required final IShareClient _client,
  required final expense.IExportRepository _repository,
}) implements IExportRepository {
  @override
  Future<PreparedExportModel?> prepare() async {
    try {
      await _client.cleanExpired();
      final document = await _repository.prepare();
      if (document == null) return null;

      _repository.validateOwner(document.ownerId);

      final date = DateTime.now();
      final day = '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
      final attachment = await _client.prepare(
        bytes: document.bytes,
        fileName: 'cordato-despesas-$day.csv',
      );
      final export = PreparedExportModel(
        attachment: attachment,
        ownerId: document.ownerId,
      );

      try {
        _repository.validateOwner(document.ownerId);

        return export;
      } on ExpenseException {
        await _client.discard(attachment);

        rethrow;
      }
    } on ExpenseException catch (exception) {
      throw ExportException(errors: exception.errors);
    } on FileShareException catch (exception) {
      throw ExportException(errors: exception.errors);
    }
  }

  @override
  Future<ShareOutcomeEnum> share({
    required PreparedExportModel export,
    ShareOriginModel? origin,
  }) async {
    try {
      _repository.validateOwner(export.ownerId);

      return await _client.share(
        origin: origin,
        mimeType: 'text/csv',
        attachment: export.attachment,
      );
    } on ExpenseException catch (exception) {
      throw ExportException(errors: exception.errors);
    } on FileShareException catch (exception) {
      throw ExportException(errors: exception.errors);
    } finally {
      await discard(export);
    }
  }

  @override
  Future<void> discard(PreparedExportModel export) async {
    try {
      await _client.discard(export.attachment);
    } on FileShareException catch (exception) {
      throw ExportException(errors: exception.errors);
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
