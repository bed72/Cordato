import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/insight/infrastructure/repositories/insight_repository.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_bloc.dart';

final insightModule = createModule(
  register: (context) => context
    ..addLazySingleton<IInsightRepository>(InsightRepository.new)
    ..add(InsightsBloc.new),
);
