import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';

final settingsModule = createModule(
  path: RouteEnum.settings.path,
  register: (context) {
    context
      ..add<LogoutBloc>(LogoutBloc.new)
      ..route(
        RouteEnum.app.path,
        child: (context, _) => SettingsScreen(
          bloc: inject<LogoutBloc>,
          onPersonalDataPressed: () => context.pushNamed(RouteEnum.user.path),
          onBackPressed: (context) => context.pop(),
        ),
      );
  },
);
