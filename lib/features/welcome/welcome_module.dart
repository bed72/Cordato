import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/welcome/presentation/screens/welcome_screen.dart';

final welcomeModule = createModule(
  path: RouteEnum.welcome.path,
  register: (context) => context.route(
    RouteEnum.app.path,
    child: (_, _) => WelcomeScreen(
      onContinueWithEmail: (BuildContext context) =>
          context.pushNamed(RouteEnum.authenticationSignIn.path),
    ),
  ),
);
