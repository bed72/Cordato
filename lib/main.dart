import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/app_widget.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/external_client.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_storage_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();
  final client = await ExternalClient.ensureInitialized(
    client: SupabaseStorageClient(
      client: StorageClient(storage: const FlutterSecureStorage()),
    ),
  );

  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: navigatorKey,
      initialRoute: RouteEnum.welcome.path,
      defaultTransition: TransitionType.none,
      child: AppWidget(
        navigatorKey: navigatorKey,
        disposeSession: client.dispose,
        sessionState: client.sessionState,
      ),
    ),
  );
}
