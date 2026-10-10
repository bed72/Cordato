import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/metrics/application/repositories/metrics_repository.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/infrastructure/remoto/metrics_remote_data_source.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';

final metricsDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IMetricsRemoteDataSource>(MetricsRemoteDataSource.new)
    ..addLazySingleton<IMetricsRepository>(MetricsRepository.new)
    ..add(GetExpenseMetricsCommand.new),
);
