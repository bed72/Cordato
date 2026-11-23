import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_operation.dart';

import '../../../../../support/core/fakes/database_remote_exception.dart';

void main() {
  group('Successful operations', () {
    test('returns the same value without creating a failure', () async {
      final value = Object();

      final stored = await runDatabaseOperation(
        operation: () async => value,
        onFailure: () => throw StateError('Unexpected failure translation'),
      );

      expect(stored, same(value));
    });

    test('supports nullable values', () async {
      final stored = await runDatabaseOperation<String?>(
        operation: () async => null,
        onFailure: () => throw StateError('Unexpected failure translation'),
      );

      expect(stored, isNull);
    });

    test('awaits void operations exactly once', () async {
      int calls = 0;

      await runDatabaseOperation<void>(
        operation: () async {
          calls++;
        },
        onFailure: () => throw StateError('Unexpected failure translation'),
      );

      expect(calls, 1);
    });
  });

  group('Operational failures', () {
    final failures = <String, Exception>{
      'filesystem': const FileSystemException('private path'),
      for (final code in [
        SqlError.SQLITE_BUSY,
        SqlError.SQLITE_LOCKED,
        SqlError.SQLITE_READONLY,
        SqlError.SQLITE_IOERR,
        SqlError.SQLITE_FULL,
        SqlError.SQLITE_CANTOPEN,
        SqlExtendedError.SQLITE_IOERR_READ,
      ])
        'SQLite $code': SqliteException(
          extendedResultCode: code,
          message: 'private diagnostic',
        ),
    };

    for (final entry in failures.entries) {
      for (final remote in [false, true]) {
        for (final asynchronous in [false, true]) {
          test(
            '${entry.key}, remote=$remote, async=$asynchronous translates once without retry',
            () async {
              final failure = remote
                  ? DatabaseRemoteException(entry.value, StackTrace.current)
                  : entry.value;
              final translated = Exception('safe application failure');
              int calls = 0;
              int translations = 0;

              Future<int> operation() {
                calls++;
                if (asynchronous) {
                  return Future<int>.error(failure);
                }
                throw failure;
              }

              await expectLater(
                runDatabaseOperation(
                  operation: operation,
                  onFailure: () {
                    translations++;
                    return translated;
                  },
                ),
                throwsA(same(translated)),
              );

              expect(calls, 1);
              expect(translations, 1);
            },
          );
        }
      }
    }
  });

  group('Unexpected failures', () {
    test('prefers the remote stack over the local wrapper stack', () async {
      final failure = StateError('unexpected');
      final remoteStack = StackTrace.fromString('remote database stack');
      final localStack = StackTrace.fromString('local wrapper stack');

      try {
        await runDatabaseOperation<int>(
          operation: () async {
            Error.throwWithStackTrace(
              DatabaseRemoteException(failure, remoteStack),
              localStack,
            );
          },
          onFailure: () => throw StateError('Unexpected failure translation'),
        );
        fail('Expected remote failure');
      } catch (error, stackTrace) {
        expect(error, same(failure));
        expect(stackTrace, same(remoteStack));
      }
    });

    final failures = <String, Object>{
      'state': StateError('unexpected'),
      'parsing': const FormatException('invalid record'),
      'type': TypeError(),
      'application': Exception('feature failure'),
      for (final code in [
        SqlError.SQLITE_ERROR,
        SqlError.SQLITE_CONSTRAINT,
        SqlError.SQLITE_CORRUPT,
        SqlError.SQLITE_TOOBIG,
      ])
        'SQLite $code': SqliteException(
          extendedResultCode: code,
          message: 'unexpected diagnostic',
        ),
    };

    for (final entry in failures.entries) {
      for (final remote in [false, true]) {
        for (final remoteStack in [false, true]) {
          test(
            '${entry.key}, remote=$remote, remoteStack=$remoteStack preserves cause and stack',
            () async {
              final stack = StackTrace.current;
              final failure = remote
                  ? DatabaseRemoteException(
                      entry.value,
                      remoteStack ? stack : null,
                    )
                  : entry.value;
              int translations = 0;

              try {
                await runDatabaseOperation<int>(
                  operation: () async {
                    Error.throwWithStackTrace(failure, stack);
                  },
                  onFailure: () {
                    translations++;
                    return Exception('unexpected translation');
                  },
                );
                fail('Expected operation failure');
              } catch (error, stackTrace) {
                expect(error, same(entry.value));
                expect(stackTrace, same(stack));
              }

              expect(translations, 0);
            },
          );
        }
      }
    }
  });
}
