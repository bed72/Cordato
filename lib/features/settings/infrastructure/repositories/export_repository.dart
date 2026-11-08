import 'package:cordato/features/core/application/models/share_origin.dart';
import 'package:cordato/features/core/application/models/file_share_outcome.dart';
import 'package:cordato/features/core/application/exceptions/file_share_exception.dart';
import 'package:cordato/features/core/application/clients/interface_file_share_client.dart';
import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/models/prepared_export_model.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';
import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart'
    as expense;

final class ExportRepository({
  required final IFileShareClient fileShareClient,
  required final expense.IExportRepository expenseRepository,
}) implements IExportRepository {
  @override
  Future<PreparedExportModel?> prepare() async {
    try {
      await fileShareClient.cleanExpired();
      final document = await expenseRepository.prepare();
      if (document == null) return null;

      expenseRepository.validateOwner(document.ownerId);
      final date = DateTime.now();
      final day = '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
      final attachment = await fileShareClient.prepare(
        bytes: document.bytes,
        fileName: 'cordato-despesas-$day.csv',
      );
      final export = PreparedExportModel(
        attachment: attachment,
        ownerId: document.ownerId,
      );

      try {
        expenseRepository.validateOwner(document.ownerId);

        return export;
      } on ExpenseException {
        await fileShareClient.discard(attachment);
        rethrow;
      } on MissingAuthenticatedUserException {
        await fileShareClient.discard(attachment);
        rethrow;
      }
    } on ExpenseException catch (exception) {
      throw ExportException(errors: exception.errors);
    } on MissingAuthenticatedUserException catch (exception) {
      throw ExportException(errors: exception.errors);
    } on FileShareException catch (exception) {
      throw ExportException(errors: exception.errors);
    }
  }

  @override
  Future<FileShareOutcome> share({
    required PreparedExportModel export,
    ShareOrigin? origin,
  }) async {
    try {
      expenseRepository.validateOwner(export.ownerId);
      return await fileShareClient.share(
        origin: origin,
        mimeType: 'text/csv',
        attachment: export.attachment,
      );
    } on ExpenseException catch (exception) {
      throw ExportException(errors: exception.errors);
    } on MissingAuthenticatedUserException catch (exception) {
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
      await fileShareClient.discard(export.attachment);
    } on FileShareException catch (exception) {
      throw ExportException(errors: exception.errors);
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
