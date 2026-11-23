import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart';

Future<T> runDatabaseOperation<T>({
  required Future<T> Function() operation,
  required Exception Function() onFailure,
}) async {
  try {
    return await operation();
  } on FileSystemException {
    throw onFailure();
  } on SqliteException catch (error, stackTrace) {
    _failure(error, stackTrace, onFailure);
  } on DriftRemoteException catch (error, stackTrace) {
    _failure(
      error.remoteCause,
      error.remoteStackTrace ?? stackTrace,
      onFailure,
    );
  }
}

Never _failure(
  Object error,
  StackTrace stackTrace,
  Exception Function() onFailure,
) {
  if (error is FileSystemException) throw onFailure();

  if (error is SqliteException &&
      const {
        SqlError.SQLITE_BUSY,
        SqlError.SQLITE_FULL,
        SqlError.SQLITE_IOERR,
        SqlError.SQLITE_LOCKED,
        SqlError.SQLITE_READONLY,
        SqlError.SQLITE_CANTOPEN,
      }.contains(error.resultCode)) {
    throw onFailure();
  }

  Error.throwWithStackTrace(error, stackTrace);
}
