import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

class _SupabaseAuthenticationClientMock extends Mock
    implements IAuthenticationClient {}

void main() {
  const code = 'magic-link-code';
  const email = 'person@example.com';

  late IAuthenticationClient client;
  late IAuthenticationDataSource dataSource;

  setUp(() {
    client = _SupabaseAuthenticationClientMock();
    dataSource = AuthenticationDataSource(client: client);
  });

  group('AuthenticationDataSource', () {
    test('delegates successful logout to the client', () async {
      when(() => client.signOut()).thenAnswer((_) async => true);

      final result = await dataSource.signOut();

      expect(result, isTrue);
      verify(() => client.signOut()).called(1);
    });

    test('delegates logout and returns the client result', () async {
      when(() => client.signOut()).thenAnswer((_) async => false);

      final result = await dataSource.signOut();

      expect(result, isFalse);
      verify(() => client.signOut()).called(1);
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
