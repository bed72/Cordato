import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/insight/application/repositories/insight_repository.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/infrastructure/remoto/insight_remote_data_source.dart';
import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';

final insightDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<IInsightRemoteDataSource>(InsightRemoteDataSource.new)
    ..addLazySingleton<IInsightRepository>(InsightRepository.new)
    ..add(GetInsightsCommand.new),
);
