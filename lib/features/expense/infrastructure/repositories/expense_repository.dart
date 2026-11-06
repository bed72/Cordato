import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

import 'package:cordato/features/core/infrastructure/serializers/date_serializer.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_suggestion_response.dart';

final class ExpenseRepository({
  required final PocketBase _pocketBase,
  required final IHomeWidgetClient _homeWidgetClient,
}) implements IExpenseRepository {
  @override
  Future<List<ExpenseSuggestionEntity>> suggestions({
    required String query,
  }) async {
    try {
      final response = await _pocketBase
          .collection('expenses')
          .getList(
            perPage: 30,
            skipTotal: true,
            sort: '-occurred_on,-created,-id',
            fields: 'id,description,amount,category',
            filter: _pocketBase.filter('description ~ {:query}', {
              'query': query,
            }),
          );

      final descriptions = <String>{};
      return .unmodifiable(
        response.items
            .map(
              (item) =>
                  ExpenseSuggestionResponse.fromJson(item.toJson()).toEntity(),
            )
            .where((item) => descriptions.add(item.description.toLowerCase())),
      );
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  @override
  Future<ExpenseEntity> getById({required String id}) async {
    try {
      final response = await _pocketBase.collection('expenses').getOne(id);

      return ExpenseResponse.fromJson(response.toJson()).toEntity();
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      await _pocketBase.collection('expenses').delete(id);

      _homeWidgetClient.requestMonthlyRefresh();
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  @override
  Future<ExpensePageEntity> get({
    int page = 1,
    int pageSize = 30,
    String? sort,
    DateTime? to,
    DateTime? from,
    String? category,
  }) async {
    try {
      final filters = [
        if (category != null)
          _pocketBase.filter('category = {:category}', {'category': category}),

        if (from != null)
          _pocketBase.filter('occurred_on >= {:from}', {'from': _date(from)}),

        if (to != null)
          _pocketBase.filter('occurred_on < {:to}', {
            'to': _date(DateTime.utc(to.year, to.month, to.day + 1)),
          }),
      ];

      final response = await _pocketBase
          .collection('expenses')
          .getList(
            page: page,
            filter: filters.join(' && '),
            sort: sort ?? '-occurred_on,-id',
            perPage: pageSize > 0 ? pageSize : 30,
          );

      return ExpensePageEntity(
        nextPage: response.page < response.totalPages
            ? response.page + 1
            : null,
        items: response.items
            .map((item) => ExpenseResponse.fromJson(item.toJson()).toEntity())
            .toList(),
      );
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  @override
  Future<ExpenseEntity> update({
    required String id,
    int? cents,
    String? description,
    DateTime? occurredOn,
    ExpenseCategoryEnum? category,
  }) async {
    try {
      final response = await _pocketBase
          .collection('expenses')
          .update(
            id,
            body: {
              'amount': ?cents,
              'description': ?description,
              'category': ?category?.value,
              if (occurredOn != null) 'occurred_on': _date(occurredOn),
            },
          );

      final updated = ExpenseResponse.fromJson(response.toJson()).toEntity();
      _homeWidgetClient.requestMonthlyRefresh();

      return updated;
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
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
      final owner = _pocketBase.userId();
      final response = await _pocketBase
          .collection('expenses')
          .create(
            body: {
              'owner': owner,
              'amount': cents,
              'category': category.value,
              'description': description,
              'occurred_on': _date(occurredOn ?? .now()),
            },
          );

      final created = ExpenseResponse.fromJson(response.toJson()).toEntity();
      _homeWidgetClient.requestMonthlyRefresh();

      return created;
    } on ClientException catch (exception) {
      throw ExpenseException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  String _date(DateTime date) => '${dateSerializer(date)} 00:00:00.000Z';
}
