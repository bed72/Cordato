import 'package:cordato/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

final welcomeModule = createModule(
  path: '/welcome',
  register: (context) => context.route(
    '/',
    child: (_, _) => WelcomeScreen(
      onContinueWithEmail: (BuildContext context) =>
          context.pushNamed('/authentication/magic-link'),
    ),
  ),
);
