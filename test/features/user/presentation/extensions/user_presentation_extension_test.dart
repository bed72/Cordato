import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/extensions/user_presentation_extension.dart';

void main() {
  for (final name in ['', '   ', '\t\n']) {
    test('displays Cordato for an empty name: ${name.codeUnits}', () {
      final user = UserEntity(
        id: 'user',
        name: name,
        email: 'person@example.com',
      );

      expect(user.displayName, 'Cordato');
      expect(user.name, name);
    });
  }

  test('preserves a supplied name without normalization', () {
    const user = UserEntity(
      id: 'user',
      name: '  Gabriel  ',
      email: 'person@example.com',
    );

    expect(user.displayName, '  Gabriel  ');
  });
}
