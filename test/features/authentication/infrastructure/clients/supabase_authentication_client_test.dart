import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthSessionUrlResponse, GoTrueClient, Session, SupabaseClient;

import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';

class _GoTrueClientMock extends Mock implements GoTrueClient {}

class _SessionMock extends Mock implements Session {}

class _AuthSessionUrlResponseMock extends Mock
    implements AuthSessionUrlResponse {}

class _SupabaseClientMock extends Mock implements SupabaseClient {}

void main() {
  const redirectUrl = 'com.cordato://login-callback';
  const email = 'person@example.com';
  const code = 'magic-link-code';

  late SupabaseClient supabaseClient;
  late GoTrueClient auth;
  late ISupabaseAuthenticationClient client;

  setUp(() {
    supabaseClient = _SupabaseClientMock();
    auth = _GoTrueClientMock();
    client = SupabaseAuthenticationClient(
      client: supabaseClient,
      redirectUrl: redirectUrl,
    );

    when(() => supabaseClient.auth).thenReturn(auth);
  });

  group('SupabaseAuthenticationClient', () {
    test('returns true when a session exists', () async {
      when(() => auth.currentSession).thenReturn(_SessionMock());

      expect(await client.checkSession(), isTrue);
    });

    test('returns false when there is no session', () async {
      when(() => auth.currentSession).thenReturn(null);

      expect(await client.checkSession(), isFalse);
    });

    test('requests a magic link', () async {
      when(
        () => auth.signInWithOtp(
          email: email,
          shouldCreateUser: true,
          emailRedirectTo: redirectUrl,
        ),
      ).thenAnswer((_) async {});

      expect(await client.requestMagicLink(email: email), isTrue);
      verify(
        () => auth.signInWithOtp(
          email: email,
          shouldCreateUser: true,
          emailRedirectTo: redirectUrl,
        ),
      ).called(1);
    });

    test('returns false when requesting a magic link fails', () async {
      when(
        () => auth.signInWithOtp(
          email: email,
          shouldCreateUser: true,
          emailRedirectTo: redirectUrl,
        ),
      ).thenThrow(Exception('request failed'));

      expect(await client.requestMagicLink(email: email), isFalse);
    });

    test('completes a magic link when a session is created', () async {
      when(() => auth.exchangeCodeForSession(code))
          .thenAnswer((_) async => _AuthSessionUrlResponseMock());
      when(() => auth.currentSession).thenReturn(_SessionMock());

      expect(await client.completeMagicLink(code: code), isTrue);
      verify(() => auth.exchangeCodeForSession(code)).called(1);
    });

    test(
      'returns false when completing a magic link leaves no session',
      () async {
        when(() => auth.exchangeCodeForSession(code))
            .thenAnswer((_) async => _AuthSessionUrlResponseMock());
        when(() => auth.currentSession).thenReturn(null);

        expect(await client.completeMagicLink(code: code), isFalse);
      },
    );

    test('returns false when completing a magic link fails', () async {
      when(() => auth.exchangeCodeForSession(code))
          .thenThrow(Exception('completion failed'));

      expect(await client.completeMagicLink(code: code), isFalse);
    });

    test('logs out successfully', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      expect(await client.logout(), isTrue);
      verify(() => auth.signOut()).called(1);
    });

    test('returns false when logout fails', () async {
      when(() => auth.signOut()).thenThrow(Exception('logout failed'));

      expect(await client.logout(), isFalse);
    });
  });
}
