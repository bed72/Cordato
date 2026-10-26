import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/serializers/civil_date_serializer.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

final class ExpenseRepository({required final IHttpClient _httpClient})
    implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async {
    try {
      final response = await _httpClient.get(
        parameter: Requests(
          query: {'query': query},
          path: '${HttpPathEnum.expenses.path}/suggestions',
        ),
      );

      return .unmodifiable(
        (response.body['data'] as List).map(
          (item) =>
              ExpenseSuggestionResponse.fromJson(item as Map<String, dynamic>)
                  .toEntity(),
        ),
      );
    } on HttpResponseException catch (exception) {
      throw ExpenseException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> getById({required String id}) async {
    try {
      final response = await _httpClient.get(
        parameter: Requests(
          path: '${HttpPathEnum.expenses.path}/${Uri.encodeComponent(id)}',
        ),
      );

      return ExpenseResponse.fromJson(response.body).toEntity();
    } on HttpResponseException catch (exception) {
      throw ExpenseException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      final response = await _httpClient.delete(
        parameter: Requests(
          path: '${HttpPathEnum.expenses.path}/${Uri.encodeComponent(id)}',
        ),
      );

      if (response.status != 204) throw ExpenseException(errors: .unknown());
    } on HttpResponseException catch (exception) {
      throw ExpenseException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpensePageEntity> get({
    String? sort,
    DateTime? to,
    DateTime? from,
    String? pageLink,
    String? category,
    int pageSize = 30,
  }) async {
    try {
      final response = await _httpClient.get(
        parameter: Requests(
          path: HttpPathEnum.expenses.path,
          query: _pageQuery(
            to: to,
            sort: sort,
            from: from,
            category: category,
            pageLink: pageLink,
            pageSize: pageSize > 0 ? pageSize : 30,
          ),
        ),
      );

      final page = ExpensePageResponse.fromJson(response.body);

      return ExpensePageEntity(
        items: page.items.map((item) => item.toEntity()).toList(),
        next: page.next,
        prev: page.prev,
      );
    } on HttpResponseException catch (exception) {
      throw ExpenseException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async {
    try {
      final response = await _httpClient.patch(
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
      );
      return ExpenseResponse.fromJson(response.body).toEntity();
    } on HttpResponseException catch (exception) {
      throw ExpenseException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw ExpenseException(errors: .unknown());
    }
  }

  @override
  Future<ExpenseEntity> create({
    required int cents,
    required String description,
    DateTime? occurredOn,
  }) async {
    try {
      final response = await _httpClient.post(
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
      );
      return ExpenseResponse.fromJson(response.body).toEntity();
    } on HttpResponseException catch (exception) {
      throw ExpenseException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw ExpenseException(errors: .unknown());
    }
  }

  Map<String, dynamic> _pageQuery({
    String? sort,
    required int pageSize,
    DateTime? to,
    DateTime? from,
    String? category,
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
    if (sort != null) query['sort'] = sort;
    if (category != null) query['filter[category]'] = category;

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
