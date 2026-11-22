import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/extensions/user_presentation_extension.dart';

void main() {
  for (final name in ['', '   ', '\t\n']) {
    test('displays Cordato for an empty name: ${name.codeUnits}', () {
      final user = UserEntity(name: name);

      expect(user.displayName, 'Cordato');
      expect(user.name, name);
    });
  }

  test('preserves a supplied name without normalization', () {
    const user = UserEntity(name: '  Gabriel  ');

    expect(user.displayName, '  Gabriel  ');
  });
}
