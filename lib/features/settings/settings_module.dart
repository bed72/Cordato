import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/settings/presentation/commands/logout_command.dart';
import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';

final settingsModule = createModule(
  path: RouteEnum.settings.path,
  register: (context) {
    context
      ..addLazySingleton<LogoutCommand>(LogoutCommand.new)
      ..route(
        RouteEnum.root.path,
        child: (_, _) => SettingsScreen(
          command: inject<LogoutCommand>(),
          onBackPressed: (context) => context.pop(),
          onHelpPressed: () {},
          onTermsPressed: () {},
          onPrivacyPressed: () {},
          onPersonalDataPressed: () {},
          onSubscriptionPressed: () {},
          onInvitePartnerPressed: () {},
        ),
      );
  },
);
