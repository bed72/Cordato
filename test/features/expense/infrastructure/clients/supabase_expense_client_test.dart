import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Request, Response;
import 'package:http/testing.dart' show MockClient;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/infrastructure/clients/supabase_expense_client.dart';
import 'package:cordato/features/expense/infrastructure/enums/expense_create_outcome_enum.dart';

void main() {
  final expense = ExpenseEntity.create(
    amount: 1500,
    description: 'Almoço',
    date: DateTime(2026, 9, 8),
  )!;

  test('creates an expense through the create_expense RPC', () async {
    Request? request;
    final client = SupabaseExpenseClient(
      client: _supabaseClient((value) async {
        request = value;
        return Response(
          '"expense-id"',
          200,
          headers: {'content-type': 'application/json'},
          request: value,
        );
      }),
    );

    expect(await client.create(expense), ExpenseCreateOutcomeEnum.created);
    expect(request?.method, 'POST');
    expect(request?.url.path, '/rest/v1/rpc/create_expense');
    expect(jsonDecode(request!.body), {
      'p_amount': 1500,
      'p_description': 'Almoço',
      'p_date': '2026-09-08',
    });
  });

  test('returns failed when the expense RPC fails', () async {
    final client = SupabaseExpenseClient(
      client: _supabaseClient((_) async => throw StateError('network error')),
    );

    expect(await client.create(expense), ExpenseCreateOutcomeEnum.failed);
  });
}

SupabaseClient _supabaseClient(Future<Response> Function(Request) handler) =>
    SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      accessToken: () async => 'test-access-token',
      httpClient: MockClient(handler),
    );
