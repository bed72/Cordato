import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

typedef CreateDataSourceType = Either<ErrorsResponse, ExpenseResponse>;

abstract interface class IExpenseRemoteDataSource {
  Future<CreateDataSourceType> create({required CreateExpenseInput input});
}

final class ExpenseRemoteDataSource({required final IHttpClient _client})
    implements IExpenseRemoteDataSource {
  @override
  Future<CreateDataSourceType> create({required CreateExpenseInput input}) =>
      response(
        from: (response) => .fromJson(response.body),
        execute: () => _client.post(
          parameter: Requests(
            path: HttpPathEnum.expenses.path,
            body: {
              'data': {
                'type': 'expenses',
                'attributes': {
                  'amount': input.cents,
                  'description': input.description,
                  'occurred_on': _formatOccurredOn(input.occurredOn),
                },
              },
            },
          ),
        ),
      );

  String _formatOccurredOn(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
