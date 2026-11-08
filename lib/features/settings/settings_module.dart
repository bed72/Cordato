import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';

import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart'
    as expense;
import 'package:cordato/features/settings/infrastructure/repositories/export_repository.dart';

import 'package:cordato/features/settings/presentation/screens/support/support_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';

final settingsModule = createModule(
  path: RouteEnum.settings.path,
  register: (context) {
    context
      ..add<LogoutBloc>(LogoutBloc.new)
      ..route(
        RouteEnum.app.path,
        provide: (scope) => scope.addBloc<ExportBloc>(
          (
            expense.IExportRepository expenseRepository,
            IShareClient fileShareClient,
          ) => ExportBloc(
            repository: ExportRepository(
              shareClient: fileShareClient,
              expenseRepository: expenseRepository,
            ),
          ),
        ),
        child: (context, _) => SettingsScreen(
          logoutBloc: inject<LogoutBloc>,
          exportBloc: context.read<ExportBloc>(),
          onBackPressed: (context) => context.pop(),
          onPersonalDataPressed: () => context.pushNamed(RouteEnum.user.path),
        ),
      )
      ..route('/support', child: (_, _) => const SupportScreen());
  },
);
