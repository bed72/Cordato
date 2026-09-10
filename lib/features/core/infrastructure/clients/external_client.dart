import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final class ExternalClient {
  final GoTrueClient _client;
  final sessionState = ValueNotifier<AuthSessionStateEnum>(.loading);
  late final StreamSubscription<AuthState> _authSubscription;
  Object? _lastSessionError;

  ExternalClient._(this._client) {
    _authSubscription = _client.onAuthStateChange.listen(
      _onAuthStateChange,
      onError: _onAuthStateError,
    );
  }

  @visibleForTesting
  ExternalClient.forClient({required GoTrueClient client}) : this._(client);

  static Future<ExternalClient> ensureInitialized({
    required LocalStorage client,
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
      authOptions: FlutterAuthClientOptions(localStorage: client),
    );

    return ExternalClient._(instance.client.auth);
  }

  bool get hasSession => _client.currentSession != null;

  Object? get lastSessionError => _lastSessionError;

  void _onAuthStateChange(AuthState state) {
    _lastSessionError = null;
    sessionState.value = switch (state.event) {
      .signedOut => .unauthenticated,
      .initialSession ||
      .passwordRecovery ||
      .signedIn ||
      .tokenRefreshed ||
      .userUpdated ||
      .mfaChallengeVerified =>
        state.session == null ? .unauthenticated : .authenticated,
      _ => state.session == null ? .unauthenticated : .authenticated,
    };
  }

  void _onAuthStateError(Object error, StackTrace _) {
    _lastSessionError = error;
    sessionState.value = .restorationFailure;
  }

  Future<void> dispose() async {
    await _authSubscription.cancel();
    sessionState.dispose();
  }
}
