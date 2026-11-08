import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/serializers/csv_serializer.dart';

import 'package:cordato/features/expense/application/models/document_model.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart';

final class ExportRepository({required final PocketBase pocketBase})
    implements IExportRepository {
  @override
  void validateOwner(String ownerId) {
    if (pocketBase.userId() != ownerId) {
      throw ExpenseException(
        errors: const ErrorsEntity(
          errors: [ErrorEntity(code: 'export_identity_changed')],
        ),
      );
    }
  }

  @override
  Future<DocumentModel?> prepare() async {
    int page = 1;
    bool hasExpenses = false;

    final ownerId = pocketBase.userId();
    final serializer = CsvSerializer();

    try {
      while (true) {
        validateOwner(ownerId);

        final records = await pocketBase
            .collection('expenses')
            .getList(
              page: page,
              perPage: 200,
              sort: 'occurred_on,id',
              fields: 'id,owner,description,amount,category,occurred_on',
              filter: pocketBase.filter('owner = {:owner}', {'owner': ownerId}),
            );

        validateOwner(ownerId);

        for (final record in records.items) {
          if (record.data['owner'] as String != ownerId) {
            throw const FormatException('Invalid expense owner');
          }

          serializer.add(ExpenseResponse.fromJson(record.toJson()));
          hasExpenses = true;
        }

        if (records.page >= records.totalPages) {
          break;
        }

        page = records.page + 1;
      }

      validateOwner(ownerId);
      return hasExpenses
          ? DocumentModel(ownerId: ownerId, bytes: serializer.takeBytes())
          : null;
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
    }
  }
}
