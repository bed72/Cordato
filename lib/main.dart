import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/app_widget.dart';

import 'package:cordato/features/core/domain/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = await SupabaseClient.ensureInitialized();

  runApp(
    ModularApp(
      module: appModule,
      defaultTransition: TransitionType.none,
      initialRoute: client.hasSession
          ? RouteEnum.dashboard.path
          : RouteEnum.welcome.path,
      child: AppWidget(events: client.events),
    ),
  );
}
