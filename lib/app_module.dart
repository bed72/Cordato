import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/welcome/welcome_module.dart';
import 'package:flutter_modular/flutter_modular.dart';

final appModule = createModule(
  register: (context) {
    context
      ..module(coreModule)
      ..module(welcomeModule)
      ..module(authenticationModule);
  },
);
