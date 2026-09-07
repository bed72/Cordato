import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final class ExternalClient {
  final GoTrueClient _client;

  const ExternalClient._(this._client);

  static Future<ExternalClient> ensureInitialized({
    String url = _supabaseUrl,
    String publishableKey = _supabaseAnonKey,
  }) async {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided with --dart-define.',
      );
    }

    final instance = await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );

    return ExternalClient._(instance.client.auth);
  }

  bool get hasSession => _client.currentSession != null;

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (_) {}
  }

  Stream<void> get events => _client.onAuthStateChange
      .where((state) => state.event == .signedIn)
      .map<void>((_) {});
}
