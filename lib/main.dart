import 'package:cordato/app_module.dart';
import 'package:cordato/app_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_ANON_KEY must be provided with --dart-define.',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );

  final authentication = Supabase.instance.client.auth;
  final events = authentication.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.signedIn)
      .map<void>((_) {});

  runApp(
    ModularApp(
      module: appModule,
      defaultTransition: TransitionType.none,
      initialRoute: authentication.currentSession == null
          ? '/welcome'
          : '/dashboard',
      child: AppWidget(events: events),
    ),
  );
}
