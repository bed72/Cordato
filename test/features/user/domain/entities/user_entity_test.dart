import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

void main() {
  group('UserEntity', () {
    test('represents a local profile with stable ID, name and seed', () {
      const user = UserEntity(id: 1, name: 'Cordato', seed: 'stable-seed');

      expect(user.id, 1);
      expect(user.name, 'Cordato');
      expect(user.seed, 'stable-seed');
    });

    test('preserves fields without form normalization', () {
      const user = UserEntity(id: 1, name: '  Nome  ', seed: '');

      expect(user.id, 1);
      expect(user.name, '  Nome  ');
      expect(user.seed, isEmpty);
    });
  });
}
