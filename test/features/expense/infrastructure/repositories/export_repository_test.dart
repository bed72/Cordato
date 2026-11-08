import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/infrastructure/repositories/export_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  late PocketBaseFixture fixture;
  late ExportRepository repository;
  const resource = {
    'id': 'expense-1',
    'owner': 'owner-id',
    'amount': 123456,
    'description': 'Café',
    'category': 'food',
    'occurred_on': '2026-11-08 00:00:00.000Z',
  };

  http.Response page({
    int number = 1,
    int total = 1,
    List<Map<String, dynamic>> items = const [resource],
  }) => PocketBaseFixture.jsonResponse({
    'page': number,
    'totalPages': total,
    'perPage': 200,
    'items': items,
  });

  setUp(() {
    fixture = PocketBaseFixture()..authenticate(id: 'owner-id');
    repository = ExportRepository(pocketBase: fixture.client);
    fixture.respond = (_) => page();
    addTearDown(fixture.client.close);
  });

  group('Own history', () {
    test(
      'reads every page with fixed owner and sort and returns immutable CSV',
      () async {
        fixture.respond = (request) {
          final number = int.parse(request.url.queryParameters['page']!);
          return page(
            number: number,
            total: 3,
            items: [
              {...resource, 'id': 'expense-$number'},
            ],
          );
        };

        final document = (await repository.prepare())!;

        expect(document.ownerId, 'owner-id');
        expect(
          utf8.decode(document.bytes),
          contains('expense-3;08/11/2026;Café;food;1234,56'),
        );
        expect(() => document.bytes[0] = 0, throwsUnsupportedError);
        expect(fixture.requests, hasLength(3));
        for (final request in fixture.requests) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/collections/expenses/records');
          expect(request.url.queryParameters['filter'], 'owner = "owner-id"');
          expect(request.url.queryParameters['sort'], 'occurred_on,id');
          expect(request.url.queryParameters['perPage'], '200');
          expect(request.headers['Authorization'], PocketBaseFixture.token);
        }
      },
    );

    test(
      'escapes the unnormalized owner through SDK filter construction',
      () async {
        fixture.authenticate(id: 'owner" || owner != "');
        fixture.respond = (_) => page(items: []);
        await repository.prepare();
        expect(
          fixture.requests.single.url.queryParameters['filter'],
          fixture.client.filter('owner = {:owner}', {
            'owner': 'owner" || owner != "',
          }),
        );
      },
    );

    test('returns no document for empty history', () async {
      fixture.respond = (_) => page(total: 0, items: []);
      expect(await repository.prepare(), isNull);
    });

    for (final owner in <String?>[null, '', '   ']) {
      test('rejects absent identity $owner before HTTP', () async {
        if (owner == null) {
          fixture.client.authStore.clear();
        } else {
          fixture.authenticate(id: owner);
        }
        await expectLater(
          repository.prepare(),
          throwsA(isA<MissingAuthenticatedUserException>()),
        );
        expect(fixture.requests, isEmpty);
      });
    }

    for (final nextOwner in <String?>[null, 'other-owner']) {
      test(
        'does not continue pagination after identity becomes $nextOwner',
        () async {
          final response = Completer<http.Response>();
          final started = Completer<void>();
          fixture.respond = (_) {
            started.complete();
            return response.future;
          };
          final pending = repository.prepare();
          final assertion = expectLater(
            pending,
            throwsA(
              nextOwner == null
                  ? isA<MissingAuthenticatedUserException>()
                  : isA<ExpenseException>(),
            ),
          );
          await started.future;
          if (nextOwner == null) {
            fixture.client.authStore.clear();
          } else {
            fixture.authenticate(id: nextOwner);
          }
          response.complete(page(total: 2));
          await assertion;
          expect(fixture.requests, hasLength(1));
          expect(fixture.client.authStore.record?.id, nextOwner);
        },
      );
    }
  });

  group('Failures', () {
    test(
      'maps native metadata from a later failure without clearing session',
      () async {
        fixture.respond = (request) =>
            request.url.queryParameters['page'] == '1'
            ? page(total: 2)
            : PocketBaseFixture.jsonResponse({
                'message': 'private',
                'data': {
                  'owner': {'code': 'forbidden', 'message': 'private'},
                },
              }, status: 401);
        await expectLater(
          repository.prepare(),
          throwsA(
            isA<ExpenseException>().having(
              (error) => error.errors.errors.first.status,
              'status',
              '401',
            ),
          ),
        );
        expect(fixture.requests, hasLength(2));
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
      },
    );

    test('maps transport failure without retry or session mutation', () async {
      fixture.respond = (_) => throw const SocketException('offline');
      await expectLater(repository.prepare(), throwsA(isA<ExpenseException>()));
      expect(fixture.requests, hasLength(1));
      expect(fixture.client.authStore.token, PocketBaseFixture.token);
    });

    for (final invalid in <String, Map<String, dynamic>>{
      'amount': {...resource, 'amount': '100'},
      'date': {...resource, 'occurred_on': 'not-a-date'},
      'category': {...resource, 'category': 'invalid'},
      'description': {...resource, 'description': null},
      'other owner': {...resource, 'owner': 'family-member'},
    }.entries) {
      test('does not publish CSV for invalid ${invalid.key}', () async {
        fixture.respond = (_) => page(items: [invalid.value]);
        await expectLater(
          repository.prepare(),
          throwsA(isNot(isA<ExpenseException>())),
        );
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
      });
    }
  });
}
