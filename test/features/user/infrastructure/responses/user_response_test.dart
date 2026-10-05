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
          'email': 'person@example.com',
          'status': 'active',
          'created_at': '2026-10-05T16:48:33+00:00',
          'updated_at': '2026-10-05T16:52:34+00:00',
        },
        'links': {'self': 'https://example.com/api/users/10'},
      },
    });

    final user = response.toEntity();
    expect(user.id, '10');
    expect(user.name, 'Trocado');
    expect(user.email, 'person@example.com');
    expect(user.status, 'active');
  });
}
