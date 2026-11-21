import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/settings/presentation/screens/support/support_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';

final settingsModule = createModule(
  register: (context) {
    context
      ..route(RouteEnum.settings.path, child: (_, _) => const SettingsScreen())
      ..route(
        RouteEnum.settingsSupport.path,
        child: (_, _) => const SupportScreen(),
      );
  },
);
