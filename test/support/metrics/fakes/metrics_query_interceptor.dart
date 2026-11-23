import 'package:drift/drift.dart';

final class MetricsQueryInterceptor extends QueryInterceptor {
  Future<void> Function()? beforeRead;
  final List<String> selects = [];
  final List<List<Object?>> arguments = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('SUM(amount)')) {
      selects.add(statement);
      arguments.add(List<Object?>.of(args));
      await beforeRead?.call();
    }
    return executor.runSelect(statement, args);
  }
}
