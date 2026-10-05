import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';
import 'package:cordato/features/authentication/presentation/commands/logout_command.dart';

final settingsModule = createModule(
  path: RouteEnum.settings.path,
  register: (context) {
    context
      ..addLazySingleton<LogoutCommand>(LogoutCommand.new)
      ..route(
        RouteEnum.root.path,
        child: (_, _) => SettingsScreen(
          command: inject<LogoutCommand>(),
          onHelpPressed: () {},
          onTermsPressed: () {},
          onPrivacyPressed: () {},
          onPersonalDataPressed: () {},
          onSubscriptionPressed: () {},
          onInvitePartnerPressed: () {},
          onBackPressed: (context) => context.pop(),
        ),
      );
  },
);
