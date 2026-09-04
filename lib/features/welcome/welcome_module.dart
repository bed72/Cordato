import 'package:cordato/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/enums/app_route.dart';

final welcomeModule = createModule(
  path: AppRoute.welcome.path,
  register: (context) => context.route(
    AppRoute.root.path,
    child: (_, _) => WelcomeScreen(
      onContinueWithEmail: (BuildContext context) =>
          context.pushNamed(AppRoute.authenticationMagicLink.path),
    ),
  ),
);
