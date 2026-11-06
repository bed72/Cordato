import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import '../../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  late PocketBaseFixture fixture;

  setUp(() {
    fixture = PocketBaseFixture();
    addTearDown(fixture.client.close);
  });

  group('session presence', () {
    test('reads local token presence without caching or HTTP', () {
      expect(fixture.client.hasSession, isFalse);

      fixture.authenticate();

      expect(fixture.client.hasSession, isTrue);

      fixture.client.authStore.clear();

      expect(fixture.client.hasSession, isFalse);
      expect(fixture.requests, isEmpty);
    });

    test('does not validate the token or require an auth record', () {
      fixture.client.authStore.save('opaque-token', null);

      expect(fixture.client.hasSession, isTrue);
      expect(fixture.client.authStore.token, 'opaque-token');
      expect(fixture.client.authStore.record, isNull);
      expect(fixture.requests, isEmpty);
    });
  });

  test('rejects a missing auth record without changing the AuthStore', () {
    expect(
      fixture.client.userId,
      throwsA(isA<MissingAuthenticatedUserException>()),
    );
    expect(fixture.client.authStore.record, isNull);
    expect(fixture.client.authStore.token, isEmpty);
    expect(fixture.requests, isEmpty);
  });

  test('reads the current identity without caching', () {
    fixture.authenticate();

    expect(fixture.client.userId(), 'user-1');

    fixture.authenticate(id: 'new-user');

    expect(fixture.client.userId(), 'new-user');

    fixture.client.authStore.clear();

    expect(
      fixture.client.userId,
      throwsA(isA<MissingAuthenticatedUserException>()),
    );
    expect(fixture.requests, isEmpty);
  });

  for (final id in ['', '   ']) {
    test('rejects an empty auth ID without changing the AuthStore: "$id"', () {
      fixture.authenticate(id: id);
      final record = fixture.client.authStore.record;

      expect(
        fixture.client.userId,
        throwsA(isA<MissingAuthenticatedUserException>()),
      );
      expect(fixture.client.authStore.record, same(record));
      expect(fixture.client.authStore.token, PocketBaseFixture.token);
      expect(fixture.requests, isEmpty);
    });
  }

  test('preserves the original valid ID without normalization', () {
    fixture.authenticate(id: ' user-1 ');
    final record = fixture.client.authStore.record;

    expect(fixture.client.userId(), ' user-1 ');
    expect(fixture.client.authStore.record, same(record));
    expect(fixture.client.authStore.token, PocketBaseFixture.token);
    expect(fixture.requests, isEmpty);
  });
}
