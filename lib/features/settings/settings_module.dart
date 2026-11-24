import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocProvider;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';

import 'package:cordato/features/settings/infrastructure/repositories/export_repository.dart';

import 'package:cordato/features/settings/presentation/screens/support/support_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';

final settingsModule = createModule(
  register: (context) {
    context
      ..addLazySingleton<IExportRepository>(ExportRepository.new)
      ..route(
        RouteEnum.settings.path,
        provide: (scope) => scope.addBloc<ExportBloc>(ExportBloc.new),
        child: (context, _) => BlocProvider.value(
          value: context.read<ExportBloc>(),
          child: const SettingsScreen(),
        ),
      )
      ..route(
        RouteEnum.settingsSupport.path,
        child: (_, _) => const SupportScreen(),
      );
  },
);
