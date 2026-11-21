import 'dart:math';

import 'package:tostore/tostore.dart';

Future<void> initializeProfile({required ToStore database}) async {
  final [name, avatar] = await Future.wait([
    database.getValue('profile.name'),
    database.getValue('profile.avatar'),
  ]);

  if (name != null && (name as String).trim().isEmpty) {
    throw const FormatException('Invalid local profile name');
  }

  if (avatar != null && (avatar as String).trim().isEmpty) {
    throw const FormatException('Invalid local profile avatar');
  }

  if (name != null && avatar != null) return;

  final random = Random.secure();
  final seed = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  final fields = {
    if (name == null) 'profile.name': 'Cordato',
    if (avatar == null) 'profile.avatar': seed,
  };

  for (final field in fields.entries) {
    final profile = await database.setValue(field.key, field.value);

    if (profile.hasErrors) throw DbException(profile.statuses);
  }
}
