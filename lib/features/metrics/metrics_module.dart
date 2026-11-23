import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';
import 'package:cordato/features/metrics/infrastructure/repositories/metrics_repository.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

final metricsModule = createModule(
  register: (context) => context
    ..addLazySingleton<MetricsDao>(MetricsDao.new)
    ..addLazySingleton<IMetricsRepository>(MetricsRepository.new),
);
