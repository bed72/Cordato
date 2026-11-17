import 'package:bloc/bloc.dart';
import 'package:talker/talker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/features/core/infrastructure/observers/observer.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_factory.dart';

Future<Module> createDependencies() async {
  if (kDebugMode) {
    Bloc.observer = Observer(
      talker: Talker(
        logger: TalkerLogger(
          settings: TalkerLoggerSettings(enableColors: false),
        ),
      ),
    );
  }

  final pocketBase = await PocketBaseFactory.create(
    url: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://pocketbase.cordato.cloud',
    ),
  );

  final supportDirectory = await getApplicationSupportDirectory();

  return createAppModule(
    pocketBase: pocketBase,
    supportDirectory: supportDirectory,
  );
}
