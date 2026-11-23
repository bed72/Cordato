import 'package:drift/drift.dart';

final class ExpenseQueryInterceptor extends QueryInterceptor {
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeInsert;
  Future<void> Function()? beforeUpdate;
  Future<void> Function()? beforeDelete;
  Future<void> Function()? beforeCommit;
  final List<String> selects = [];
  final List<String> writes = [];
  int inserts = 0;
  int updates = 0;
  int deletions = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (RegExp(r'\bexpenses\b').hasMatch(statement)) {
      final sql = statement.trimLeft();
      if (sql.startsWith('INSERT')) {
        inserts++;
        writes.add(statement);
        await beforeInsert?.call();
      } else if (sql.startsWith('UPDATE')) {
        updates++;
        writes.add(statement);
        await beforeUpdate?.call();
      } else {
        selects.add(statement);
        await beforeRead?.call();
      }
    }
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('"expenses"')) {
      updates++;
      writes.add(statement);
      await beforeUpdate?.call();
    }
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('"expenses"')) {
      deletions++;
      writes.add(statement);
      await beforeDelete?.call();
    }
    return executor.runDelete(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await beforeCommit?.call();
    await inner.send();
  }
}
