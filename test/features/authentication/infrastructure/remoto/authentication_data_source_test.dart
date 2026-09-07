import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

class _SupabaseAuthenticationClientMock extends Mock
    implements IAuthenticationClient {}

void main() {
  const email = 'person@example.com';
  const code = 'magic-link-code';

  late IAuthenticationClient client;
  late IAuthenticationDataSource dataSource;

  setUp(() {
    client = _SupabaseAuthenticationClientMock();
    dataSource = AuthenticationDataSource(client: client);
  });

  group('AuthenticationDataSource', () {
    test('delegates logout and returns the client result', () async {
      when(() => client.logout()).thenAnswer((_) async => false);

      final result = await dataSource.logout();

      expect(result, isFalse);
      verify(() => client.logout()).called(1);
    });

    test('delegates session check and returns the client result', () async {
      when(() => client.checkSession()).thenAnswer((_) async => true);

      final result = await dataSource.checkSession();

      expect(result, isTrue);
      verify(() => client.checkSession()).called(1);
    });

    test('delegates magic link requests with the email', () async {
      when(() => client.requestMagicLink(email: email))
          .thenAnswer((_) async => true);

      final result = await dataSource.requestMagicLink(email: email);

      expect(result, isTrue);
      verify(() => client.requestMagicLink(email: email)).called(1);
    });

    test('delegates code confirmation with the email and code', () async {
      when(() => client.confirmCode(email: email, code: code))
          .thenAnswer((_) async => false);

      final result = await dataSource.confirmCode(email: email, code: code);

      expect(result, isFalse);
      verify(() => client.confirmCode(email: email, code: code)).called(1);
    });
  });
}
