import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

void main() {
  group('UserEntity', () {
    test('represents local personalization without an account', () {
      const user = UserEntity(name: 'Cordato', avatar: 'stable-seed');

      expect(user.name, 'Cordato');
      expect(user.avatar, 'stable-seed');
    });

    test('allows an absent avatar without changing the name', () {
      const user = UserEntity(name: 'Cordato');

      expect(user.avatar, isNull);
      expect(user.name, 'Cordato');
    });
  });
}
