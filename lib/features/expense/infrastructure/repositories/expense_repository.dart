import 'dart:convert';

import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/serializers/civil_date_serializer.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

final class ExpenseRepository({
  required final IHttpClient _httpClient,
  required final IStorageClient _storageClient,
  required final IHomeWidgetClient _homeWidgetClient,
}) implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async {
    try {
      final response = await _httpClient.get(
        parameter: Requests(
          query: {
            'page': 1,
            'perPage': 30,
            'skipTotal': true,
            'sort': '-occurred_on,-created,-id',
            'fields': 'id,description,amount,category',
            'filter': 'description ~ ${_filter(query)}',
          },
          path: HttpPathEnum.expenseRecords.path,
        ),
      );

      final descriptions = <String>{};
      return .unmodifiable(
        (response.body['items'] as List)
            .map(
              (item) => ExpenseSuggestionResponse.fromJson(
                item as Map<String, dynamic>,
              ).toEntity(),
            )
            .where((item) => descriptions.add(item.description.toLowerCase())),
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
          path:
              '${HttpPathEnum.expenseRecords.path}/${Uri.encodeComponent(id)}',
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
          path:
              '${HttpPathEnum.expenseRecords.path}/${Uri.encodeComponent(id)}',
        ),
      );

      if (response.status != 204) throw ExpenseException(errors: .unknown());
      _homeWidgetClient.requestMonthlyRefresh();
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
      final query = _pageQuery(
        to: to,
        sort: sort,
        from: from,
        category: category,
        pageLink: pageLink,
        pageSize: pageSize > 0 ? pageSize : 30,
      );
      final response = await _httpClient.get(
        parameter: Requests(
          path: HttpPathEnum.expenseRecords.path,
          query: query,
        ),
      );

      final page = ExpensePageResponse.fromJson(response.body);

      return ExpensePageEntity(
        next: _continuation(page.next, query),
        prev: _continuation(page.prev, query),
        items: page.items.map((item) => item.toEntity()).toList(),
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
    ExpenseCategoryEnum? category,
    int? cents,
    String? description,
    DateTime? occurredOn,
  }) async {
    try {
      final response = await _httpClient.patch(
        parameter: Requests(
          path:
              '${HttpPathEnum.expenseRecords.path}/${Uri.encodeComponent(id)}',
          body: {
            'amount': ?cents,
            'category': ?category?.value,
            'description': ?description,
            if (occurredOn != null) 'occurred_on': _date(occurredOn),
          },
        ),
      );

      final updated = ExpenseResponse.fromJson(response.body).toEntity();
      _homeWidgetClient.requestMonthlyRefresh();

      return updated;
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
    ExpenseCategoryEnum category = .other,
    DateTime? occurredOn,
  }) async {
    try {
      final owner = await _storageClient.read(key: StorageKeyEnum.userId.key);

      if (owner == null || owner.trim().isEmpty) {
        throw ExpenseException(errors: .unknown());
      }

      final response = await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.expenseRecords.path,
          body: {
            'owner': owner,
            'amount': cents,
            'description': description,
            'category': category.value,
            'occurred_on': _date(occurredOn ?? .now()),
          },
        ),
      );

      final created = ExpenseResponse.fromJson(response.body).toEntity();
      _homeWidgetClient.requestMonthlyRefresh();

      return created;
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
    final query = <String, dynamic>{'page': 1};

    if (pageLink != null) {
      final uri = Uri.parse(pageLink);
      final page = int.tryParse(uri.queryParameters['page'] ?? '');
      if (page == null || page < 1 || uri.fragment.isNotEmpty) {
        throw FormatException('Link de paginação inválido');
      }

      query['page'] = page;
      for (final key in ['filter', 'sort']) {
        if (uri.queryParameters.containsKey(key)) {
          query[key] = uri.queryParameters[key];
        }
      }
    }

    query['perPage'] = pageSize;
    query['sort'] = sort ?? query['sort'] ?? '-occurred_on,-id';
    if (category != null || from != null || to != null) {
      query['filter'] = [
        if (category != null) 'category = ${_filter(category)}',
        if (from != null) 'occurred_on >= ${_filter(_date(from))}',
        if (to != null)
          'occurred_on < ${_filter(_date(DateTime.utc(to.year, to.month, to.day + 1)))}',
      ].join(' && ');
    }

    return query;
  }

  String _date(DateTime date) => '${formatDateSerializer(date)} 00:00:00.000Z';

  String _filter(String value) => jsonEncode(value);

  String? _continuation(String? link, Map<String, dynamic> query) {
    if (link == null) return null;
    return Uri(
      queryParameters: {
        for (final entry in query.entries) entry.key: entry.value.toString(),
        'page': Uri.parse(link).queryParameters['page']!,
      },
    ).toString();
  }
}
