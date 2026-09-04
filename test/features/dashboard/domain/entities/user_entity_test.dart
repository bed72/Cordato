import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';

void main() {
  test('uses the profile name as the nickname', () {
    const user = UserEntity(name: 'Gabriel Ramos');

    expect(user.nickname, 'Gabriel Ramos');
  });

  test('uses the email local part when the profile has no name', () {
    const user = UserEntity(email: 'gabriel@example.com');

    expect(user.nickname, 'gabriel');
  });

  test('uses a generic nickname when no user data is available', () {
    const user = UserEntity();

    expect(user.nickname, 'Usuário');
  });
}
