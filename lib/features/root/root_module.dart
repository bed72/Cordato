import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_launch_repository.dart';
import 'package:cordato/features/root/infrastructure/repositories/home_widget_launch_repository.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';

import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/infrastructure/repositories/home_widget_sync_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_sync_repository.dart';

final rootModule = createModule(
  register: (context) => context
    ..addLazySingleton<IHomeWidgetLaunchRepository>(
      HomeWidgetLaunchRepository.new,
    )
    ..add(HomeWidgetLaunchBloc.new)
    ..addLazySingleton<IHomeWidgetSyncRepository>(HomeWidgetSyncRepository.new)
    ..add(HomeWidgetSyncBloc.new),
);
