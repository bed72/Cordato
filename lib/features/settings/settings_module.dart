import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';

import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart';

import 'package:cordato/features/settings/infrastructure/repositories/export_repository.dart';

import 'package:cordato/features/settings/presentation/screens/support/support_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';

final settingsModule = createModule(
  register: (context) {
    context
      ..route(
        RouteEnum.settings.path,
        provide: (scope) => scope.addBloc<ExportBloc>(
          (IShareClient client, IExportRepository repository) => ExportBloc(
            repository: ExportRepository(
              client: client,
              repository: repository,
            ),
          ),
        ),
        child: (context, _) =>
            SettingsScreen(exportBloc: context.read<ExportBloc>()),
      )
      ..route(
        RouteEnum.settingsSupport.path,
        child: (_, _) => const SupportScreen(),
      );
  },
);
