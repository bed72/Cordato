import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/information/presentation/screens/help/help_screen.dart';
import 'package:cordato/features/information/presentation/screens/terms/terms_screen.dart';
import 'package:cordato/features/information/presentation/screens/privacy/privacy_screen.dart';

final informationModule = createModule(
  register: (context) => context
    ..route(
      RouteEnum.informationTerms.path,
      child: (_, _) => const TermsScreen(),
    )
    ..route(
      RouteEnum.informationPrivacy.path,
      child: (_, _) => const PrivacyScreen(),
    )
    ..route(
      RouteEnum.informationHelp.path,
      child: (_, _) => const HelpScreen(),
    ),
);
