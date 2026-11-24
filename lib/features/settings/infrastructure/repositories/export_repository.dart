import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client_exception.dart';

import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_export_repository.dart';

final class ExportRepository({
  required final IShareClient _shareClient,
  required final IExpenseExportRepository _repository,
}) implements IExportRepository {
  @override
  Future<String?> prepare() => _run(() async {
    final bytes = await _repository.prepare();
    if (bytes == null) return null;

    final date = DateTime.now();
    final day =
        '${date.year.toString().padLeft(4, '0')}-${_pad(date.month)}-${_pad(date.day)}';

    return _shareClient.prepare(
      bytes: bytes,
      fileName: 'cordato-despesas-$day.csv',
    );
  });

  @override
  Future<void> share({required String path}) =>
      _run(() => _shareClient.share(path: path, mimeType: 'text/csv'));

  @override
  Future<void> discard({required String path}) =>
      _run(() => _shareClient.discard(path: path));

  String _pad(int value) => value.toString().padLeft(2, '0');

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ExpenseException catch (error) {
      throw ExportException(errors: error.errors);
    } on ShareClientException catch (error) {
      throw ExportException(
        errors: ErrorsEntity(errors: [ErrorEntity(code: error.code)]),
      );
    }
  }
}
