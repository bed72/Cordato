import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';

final metricsModule = createModule(
  register: (context) => context.add(ExpenseMetricsBloc.new),
);
