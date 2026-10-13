import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

void main() {
  test('maps the JSON:API user into its domain representation', () {
    final response = UserResponse.fromJson({
      'data': {
        'id': '10',
        'type': 'users',
        'attributes': {
          'name': 'Trocado',
          'status': 'active',
          'avatar': 'chosen-avatar',
          'email': 'person@example.com',
          'created_at': '2026-10-05T16:48:33+00:00',
          'updated_at': '2026-10-05T16:52:34+00:00',
        },
        'links': {'self': 'https://example.com/api/users/10'},
      },
    });

    final user = response.toEntity();
    expect(user.id, '10');
    expect(user.name, 'Trocado');
    expect(user.status, 'active');
    expect(user.avatar, 'chosen-avatar');
    expect(user.email, 'person@example.com');
  });

  for (final attributes in [
    <String, dynamic>{},
    <String, dynamic>{'avatar': null},
  ]) {
    test('accepts a user without an avatar seed: $attributes', () {
      final response = UserResponse.fromJson({
        'data': {
          'id': '10',
          'attributes': {
            'name': 'Gabriel',
            'status': 'active',
            'email': 'person@example.com',
            ...attributes,
          },
        },
      });

      expect(response.avatar, isNull);
      expect(response.toEntity().avatar, isNull);
    });
  }

  test('rejects an avatar seed with an invalid type', () {
    expect(
      () => UserResponse.fromJson({
        'data': {
          'id': '10',
          'attributes': {
            'avatar': 123,
            'name': 'Gabriel',
            'status': 'active',
            'email': 'person@example.com',
          },
        },
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
