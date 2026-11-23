import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserRepository({required final DatabaseClient _database})
    implements IUserRepository {
  @override
  Future<UserEntity> get() async {
    try {
      return await _database.transaction(_handle);
    } on FileSystemException {
      throw UserException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }
  }

  @override
  Future<UserEntity> update({String? name, String? seed}) async {
    try {
      return await _database.transaction(() async {
        final current = await _handle();
        if (name == null && seed == null) return current;

        await (_database.update(
          _database.profilesTable,
        )..where((profile) => profile.id.equals(current.id))).write(
          ProfilesTableCompanion(
            name: name == null ? const .absent() : Value(name),
            seed: seed == null ? const .absent() : Value(seed),
          ),
        );

        final stored = await _database
            .select(_database.profilesTable)
            .getSingle();

        return UserResponse.fromRecord(stored).toEntity();
      });
    } on FileSystemException {
      throw UserException(errors: .unknown());
    } on SqliteException catch (error, stackTrace) {
      _failure(error, stackTrace);
    } on DriftRemoteException catch (error, stackTrace) {
      _failure(error.remoteCause, error.remoteStackTrace ?? stackTrace);
    }
  }

  Future<UserEntity> _handle() async {
    final data = await _database
        .select(_database.profilesTable)
        .getSingleOrNull();

    if (data != null) return UserResponse.fromRecord(data).toEntity();

    final profile = await _database
        .into(_database.profilesTable)
        .insertReturning(
          ProfilesTableCompanion.insert(name: 'Cordato', seed: _seed()),
        );

    return UserResponse.fromRecord(profile).toEntity();
  }

  String _seed() {
    final random = Random.secure();

    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Never _failure(Object error, StackTrace stackTrace) {
    if (error is FileSystemException) {
      throw UserException(errors: .unknown());
    }

    if (error is SqliteException &&
        const {
          SqlError.SQLITE_BUSY,
          SqlError.SQLITE_FULL,
          SqlError.SQLITE_IOERR,
          SqlError.SQLITE_LOCKED,
          SqlError.SQLITE_READONLY,
          SqlError.SQLITE_CANTOPEN,
        }.contains(error.resultCode)) {
      throw UserException(errors: .unknown());
    }

    Error.throwWithStackTrace(error, stackTrace);
  }
}
