import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

void main() {
  const record = {
    'id': 'user12345678901',
    'verified': true,
    'name': 'Gabriel',
    'collectionName': 'users',
    'avatar': 'chosen-avatar',
    'email': 'person@example.com',
  };

  test('maps a native PocketBase record without a status field', () {
    final user = UserResponse.fromJson(record).toEntity();

    expect(user.id, record['id']);
    expect(user.name, 'Gabriel');
    expect(user.email, 'person@example.com');
    expect(user.avatar, 'chosen-avatar');
  });

  test('preserves an empty name and maps an empty avatar to absence', () {
    final user = UserResponse.fromJson({...record, 'name': '', 'avatar': ''})
        .toEntity();

    expect(user.name, isEmpty);
    expect(user.avatar, isNull);
  });

  test('preserves the original name and avatar seed', () {
    final user = UserResponse.fromJson({
      ...record,
      'name': '  Nome  ',
      'avatar': '  seed  ',
    }).toEntity();

    expect(user.name, '  Nome  ');
    expect(user.avatar, '  seed  ');
  });

  for (final field in ['id', 'name', 'email', 'avatar']) {
    for (final invalid in [null, 123, false]) {
      test('rejects invalid $field: $invalid', () {
        expect(
          () => UserResponse.fromJson({...record, field: invalid}),
          throwsA(isA<TypeError>()),
        );
      });
    }

    test('rejects missing $field', () {
      final json = {...record}..remove(field);
      expect(() => UserResponse.fromJson(json), throwsA(isA<TypeError>()));
    });
  }

  test('rejects the legacy JSON:API envelope', () {
    expect(
      () => UserResponse.fromJson({'data': record}),
      throwsA(isA<TypeError>()),
    );
  });
}
