import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/serializers/civil_date_serializer.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';

typedef DeleteDataSourceType = Either<ErrorsResponse, bool>;
typedef CreateDataSourceType = Either<ErrorsResponse, ExpenseResponse>;
typedef UpdateDataSourceType = Either<ErrorsResponse, ExpenseResponse>;
typedef GetDataSourceType = Either<ErrorsResponse, ExpensePageResponse>;
typedef GetByIdDataSourceType = Either<ErrorsResponse, ExpenseResponse>;

abstract interface class IExpenseRemoteDataSource {
  Future<DeleteDataSourceType> delete({required String id});

  Future<GetByIdDataSourceType> getById({required String id});

  Future<GetDataSourceType> get({
    required int pageSize,
    DateTime? to,
    DateTime? from,
    String? pageLink,
  });

  Future<CreateDataSourceType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  });

  Future<UpdateDataSourceType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  });
}

final class ExpenseRemoteDataSource({required final IHttpClient _client})
    implements IExpenseRemoteDataSource {
  @override
  Future<GetByIdDataSourceType> getById({required String id}) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.get(
      parameter: Requests(
        path: '${HttpPathEnum.expenses.path}/${Uri.encodeComponent(id)}',
      ),
    ),
  );

  @override
  Future<DeleteDataSourceType> delete({required String id}) => response(
    from: (response) => response.statusCode == 204,
    execute: () => _client.delete(
      parameter: Requests(
        path: '${HttpPathEnum.expenses.path}/${Uri.encodeComponent(id)}',
      ),
    ),
  );

  @override
  Future<GetDataSourceType> get({
    required int pageSize,
    DateTime? to,
    DateTime? from,
    String? pageLink,
  }) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.get(
      parameter: Requests(
        path: HttpPathEnum.expenses.path,
        query: _pageQuery(
          to: to,
          from: from,
          pageSize: pageSize,
          pageLink: pageLink,
        ),
      ),
    ),
  );

  @override
  Future<UpdateDataSourceType> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.patch(
      parameter: Requests(
        path: '${HttpPathEnum.expenses.path}/${Uri.encodeComponent(id)}',
        body: {
          'data': {
            'type': 'expenses',
            'attributes': {
              'amount': ?cents,
              'description': ?description,
              if (occurredOn != null)
                'occurred_on': formatDateSerializer(occurredOn),
            },
          },
        },
      ),
    ),
  );

  @override
  Future<CreateDataSourceType> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.post(
      parameter: Requests(
        path: HttpPathEnum.expenses.path,
        body: {
          'data': {
            'type': 'expenses',
            'attributes': {
              'amount': cents,
              'description': description,
              'occurred_on': formatDateSerializer(occurredOn ?? .now()),
            },
          },
        },
      ),
    ),
  );

  Map<String, dynamic> _pageQuery({
    required int pageSize,
    DateTime? to,
    DateTime? from,
    String? pageLink,
  }) {
    final query = <String, dynamic>{};

    if (pageLink != null) {
      final uri = Uri.parse(pageLink);
      if (!uri.hasQuery || uri.fragment.isNotEmpty) {
        throw FormatException('Link de paginação inválido');
      }

      for (final entry in uri.queryParametersAll.entries) {
        query[entry.key] = entry.value.length == 1
            ? entry.value.single
            : entry.value;
      }
    }
    query['page[size]'] = pageSize;

    if (from != null || to != null) {
      query.remove('filter[year]');
      query.remove('filter[month]');
      query.remove('filter[day]');
    }
    if (from != null) query['filter[from]'] = formatDateSerializer(from);
    if (to != null) query['filter[to]'] = formatDateSerializer(to);

    return query;
  }
}
