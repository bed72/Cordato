import 'dart:io';
import 'dart:math';

import 'package:localstore/localstore.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserRepository({required final Localstore database})
    implements IUserRepository {
  @override
  Future<UserEntity> get() async {
    try {
      final document = database.collection('user').doc('profile');
      final stored = await document.get();

      if (stored != null) return UserResponse.fromJson(stored).toEntity();

      final random = Random.secure();
      final profile = {
        'name': 'Cordato',
        'avatar': List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
      };

      await document.set(profile);

      return UserResponse.fromJson(profile).toEntity();
    } on FileSystemException {
      throw UserException(errors: .unknown());
    }
  }

  @override
  Future<UserEntity> update({String? name, String? avatar}) async {
    final current = await get();

    if (name == null && avatar == null) return current;

    final profile = {
      'name': name ?? current.name,
      'avatar': avatar ?? current.avatar,
    };

    try {
      await database.collection('user').doc('profile').set(profile);

      return UserResponse.fromJson(profile).toEntity();
    } on FileSystemException {
      throw UserException(errors: .unknown());
    }
  }
}
