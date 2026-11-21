import 'dart:io';

import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserRepository({required final ToStore database})
    implements IUserRepository {
  @override
  Future<UserEntity> get() async {
    try {
      final [name, avatar] = await Future.wait([
        database.getValue('profile.name'),
        database.getValue('profile.avatar'),
      ]);

      if (name == null || avatar == null) {
        throw UserException(
          errors: const ErrorsEntity(
            errors: [ErrorEntity(code: 'profile_missing')],
          ),
        );
      }

      return UserResponse.fromJson({'name': name, 'avatar': avatar}).toEntity();
    } on DbException catch (exception) {
      throw _failure(exception);
    } on FileSystemException {
      throw UserException(errors: .unknown());
    }
  }

  @override
  Future<UserEntity> update({String? name, String? avatar}) async {
    final current = await get();

    if (name == null && avatar == null) return current;

    final fields = {'profile.name': ?name, 'profile.avatar': ?avatar};

    try {
      for (final field in fields.entries) {
        final saved = await database.setValue(field.key, field.value);

        if (saved.hasErrors) throw _failure(DbException(saved.statuses));
      }

      return await get();
    } on DbException catch (exception) {
      throw _failure(exception);
    } on FileSystemException {
      throw UserException(errors: .unknown());
    }
  }

  UserException _failure(DbException exception) {
    if (exception.statuses.any((status) => status.isDeveloperError)) {
      throw exception;
    }

    return UserException(
      errors: ErrorsEntity(
        errors: exception.statuses.isEmpty
            ? ErrorsEntity.unknown().errors
            : .unmodifiable(
                exception.statuses.map(
                  (status) => ErrorEntity(code: status.codeKey),
                ),
              ),
      ),
    );
  }
}
