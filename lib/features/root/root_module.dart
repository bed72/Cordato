import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_launch_repository.dart';
import 'package:cordato/features/root/infrastructure/repositories/widget_launch_repository.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_bloc.dart';

import 'package:cordato/features/root/presentation/bloc/widget_sync_bloc.dart';
import 'package:cordato/features/root/infrastructure/repositories/widget_sync_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_sync_repository.dart';

final rootModule = createModule(
  register: (context) => context
    ..addLazySingleton<IWidgetLaunchRepository>(WidgetLaunchRepository.new)
    ..add(WidgetLaunchBloc.new)
    ..addLazySingleton<IWidgetSyncRepository>(WidgetSyncRepository.new)
    ..add(WidgetSyncBloc.new),
);
