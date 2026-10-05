import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

void main() {
  group('UserEntity', () {
    test('represents the user independently of the JSON:API envelope', () {
      final user = UserEntity(
        id: '10',
        name: 'Trocado',
        status: 'active',
        email: 'developer.bed@gmail.com',
        createdAt: DateTime.parse('2026-10-05T16:48:33+00:00'),
      );

      expect(user.id, '10');
      expect(user.name, 'Trocado');
      expect(user.status, 'active');
      expect(user.email, 'developer.bed@gmail.com');
      expect(user.createdAt, DateTime.utc(2026, 10, 5, 16, 48, 33));
    });
  });
}
