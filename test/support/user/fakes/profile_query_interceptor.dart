import 'package:drift/drift.dart';

final class ProfileQueryInterceptor extends QueryInterceptor {
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeInsert;
  Future<void> Function()? beforeUpdate;
  Future<void> Function()? beforeCommit;
  int insertions = 0;
  int updates = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('"profiles"')) {
      if (statement.startsWith('INSERT')) {
        insertions++;
        await beforeInsert?.call();
      } else {
        await beforeRead?.call();
      }
    }

    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('"profiles"')) {
      insertions++;
      await beforeInsert?.call();
    }

    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('"profiles"')) {
      updates++;
      await beforeUpdate?.call();
    }

    return executor.runUpdate(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await beforeCommit?.call();

    await inner.send();
  }
}
