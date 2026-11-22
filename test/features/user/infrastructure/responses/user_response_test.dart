import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

void main() {
  const record = {'name': 'Gabriel', 'avatar': 'chosen-avatar'};

  test('maps the local profile without account fields', () {
    final user = UserResponse.fromJson(record).toEntity();

    expect(user.name, 'Gabriel');
    expect(user.avatar, 'chosen-avatar');
  });

  test('preserves empty name and avatar without normalization', () {
    final user = UserResponse.fromJson({...record, 'name': '', 'avatar': ''})
        .toEntity();

    expect(user.name, isEmpty);
    expect(user.avatar, isEmpty);
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

  for (final field in ['name', 'avatar']) {
    for (final invalid in [123, false]) {
      test('rejects invalid $field: $invalid', () {
        expect(
          () => UserResponse.fromJson({...record, field: invalid}),
          throwsA(isA<TypeError>()),
        );
      });
    }
  }

  test('rejects a null name', () {
    expect(
      () => UserResponse.fromJson({...record, 'name': null}),
      throwsA(isA<TypeError>()),
    );
  });

  test('rejects a missing name', () {
    final json = {...record}..remove('name');

    expect(() => UserResponse.fromJson(json), throwsA(isA<TypeError>()));
  });

  test('accepts an absent avatar', () {
    final json = {...record}..remove('avatar');

    expect(UserResponse.fromJson(json).toEntity().avatar, isNull);
  });

  test('accepts an explicitly null avatar', () {
    expect(
      UserResponse.fromJson({...record, 'avatar': null}).toEntity().avatar,
      isNull,
    );
  });
  test('rejects the legacy JSON:API envelope', () {
    expect(
      () => UserResponse.fromJson({'data': record}),
      throwsA(isA<TypeError>()),
    );
  });
}
