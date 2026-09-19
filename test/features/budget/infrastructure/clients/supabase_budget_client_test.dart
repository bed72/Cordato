import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Request, Response;
import 'package:http/testing.dart' show MockClient;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/infrastructure/clients/supabase_budget_client.dart';
import 'package:cordato/features/budget/infrastructure/enums/budget_create_outcome_enum.dart';

void main() {
  final budget = BudgetEntity.create(
    amount: 100000,
    endDate: DateTime(2026, 9, 30),
    startDate: DateTime(2026, 9, 1),
  )!;

  test('creates a budget through the create_budget RPC', () async {
    Request? request;
    final client = SupabaseBudgetClient(
      client: _supabaseClient((value) async {
        request = value;
        return Response(
          '"budget-id"',
          200,
          headers: {'content-type': 'application/json'},
          request: value,
        );
      }),
    );

    expect(await client.create(budget), BudgetCreateOutcomeEnum.created);
    expect(request?.method, 'POST');
    expect(request?.url.path, '/rest/v1/rpc/create_budget');
    expect(jsonDecode(request!.body), {
      'p_amount': 100000,
      'p_end_date': '2026-09-30',
      'p_start_date': '2026-09-01',
    });
  });

  test(
    'maps an overlapping budget RPC error to the expected outcome',
    () async {
      final client = SupabaseBudgetClient(
        client: _supabaseClient(
          (value) async => Response(
            '{"code":"23P01","message":"Budget overlaps an existing period"}',
            409,
            headers: {'content-type': 'application/json'},
            request: value,
          ),
        ),
      );

      expect(await client.create(budget), BudgetCreateOutcomeEnum.overlapping);
    },
  );

  test('returns failed for an unexpected budget RPC error', () async {
    final client = SupabaseBudgetClient(
      client: _supabaseClient((_) async => throw StateError('network error')),
    );

    expect(await client.create(budget), BudgetCreateOutcomeEnum.failed);
  });
}

SupabaseClient _supabaseClient(Future<Response> Function(Request) handler) =>
    SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      accessToken: () async => 'test-access-token',
      httpClient: MockClient(handler),
    );
