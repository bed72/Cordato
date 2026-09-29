import 'package:cordato/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

final welcomeModule = createModule(
  path: RouteEnum.welcome.path,
  register: (context) => context.route(
    RouteEnum.root.path,
    child: (_, _) => WelcomeScreen(
      onContinueWithEmail: (BuildContext context) =>
          context.pushNamed(RouteEnum.authenticationSignIn.path),
    ),
  ),
);
