import 'dart:math';

import 'package:tostore/tostore.dart';

Future<void> initializeProfile({required ToStore database}) async {
  final profile = await database.getValue('profile');

  if (profile != null) {
    final fields = profile as Map;
    final name = fields['name'] as String;
    final avatar = fields['avatar'] as String;

    if (name.trim().isEmpty || avatar.trim().isEmpty) {
      throw const FormatException('Invalid local profile');
    }

    return;
  }

  final random = Random.secure();
  final seed = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final profileWrite = await database.setValue('profile', {
    'name': 'Cordato',
    'avatar': seed,
  });

  if (profileWrite.hasErrors) {
    throw DbException(profileWrite.statuses);
  }
}
