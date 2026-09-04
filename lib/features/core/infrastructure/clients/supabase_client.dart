import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final class SupabaseClient {
  final supabase.GoTrueClient _authentication;

  const SupabaseClient._(this._authentication);

  static Future<SupabaseClient> ensureInitialized({
    String url = _supabaseUrl,
    String publishableKey = _supabaseAnonKey,
  }) async {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided with --dart-define.',
      );
    }

    final instance = await supabase.Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );

    return SupabaseClient._(instance.client.auth);
  }

  bool get hasSession => _authentication.currentSession != null;

  Stream<void> get events => _authentication.onAuthStateChange
      .where((state) => state.event == supabase.AuthChangeEvent.signedIn)
      .map<void>((_) {});
}
