import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';

import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

class _AuthenticationClientMock extends Mock implements IAuthenticationClient {}

void main() {
  const password = 'secret';
  const email = 'person@example.com';

  late IAuthenticationClient client;
  late IAuthenticationDataSource dataSource;

  setUp(() {
    client = _AuthenticationClientMock();
    dataSource = AuthenticationDataSource(client: client);
  });

  group('AuthenticationDataSource', () {
    test('sign-in returns the parsed access token response', () async {
      when(() => client.signIn(email: email, password: password)).thenAnswer(
        (_) async => Right({
          'data': {
            'id': '2',
            'attributes': {
              'token_type': 'Bearer',
              'token': 'example-token',
              'expires_at': '2026-09-28T18:30:06+00:00',
            },
            'relationships': {
              'user': {
                'data': {'type': 'users', 'id': '5'},
              },
            },
          },
        }),
      );

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isRight, isTrue);
      expect(data.right.userId, '5');
      expect(data.right.token, 'example-token');
      expect(data.right.expiresAt, DateTime.utc(2026, 9, 28, 18, 30, 6));
      verify(() => client.signIn(email: email, password: password)).called(1);
    });

    test('sign-up returns the parsed registration response', () async {
      when(() => client.signUp(email: email, password: password)).thenAnswer(
        (_) async => Right({
          'data': {'id': '3'},
        }),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isRight, isTrue);
      expect(data.right.userId, '3');
      verify(() => client.signUp(email: email, password: password)).called(1);
    });

    test('preserves all API errors from a failed sign-in', () async {
      when(() => client.signIn(email: email, password: password)).thenAnswer(
        (_) async => Left({
          'errors': [
            {
              'status': '401',
              'detail': 'Confira o e-mail.',
              'title': 'Credenciais inválidas',
              'source': {'pointer': '/data/attributes/email'},
            },
            {'detail': 'Confira a senha.', 'status': '401'},
          ],
        }),
      );

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors, hasLength(2));
      expect(data.left.errors.first.status, '401');
      expect(data.left.errors.last.detail, 'Confira a senha.');
      expect(data.left.errors.first.title, 'Credenciais inválidas');
      expect(data.left.errors.first.pointer, '/data/attributes/email');
    });

    test('preserves API errors from a failed sign-up', () async {
      when(() => client.signUp(email: email, password: password)).thenAnswer(
        (_) async => Left({
          'errors': [
            {'detail': 'E-mail já cadastrado.', 'status': '422'},
          ],
        }),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, 'E-mail já cadastrado.');
    });

    test('returns an error for a malformed success response', () async {
      when(() => client.signIn(email: email, password: password))
          .thenAnswer((_) async => const Right({}));

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('rejects a sign-in response without a user relationship', () async {
      when(() => client.signIn(email: email, password: password)).thenAnswer(
        (_) async => const Right({
          'data': {
            'id': '2',
            'attributes': {
              'token': 'example-token',
              'expires_at': '2026-09-28T18:30:06+00:00',
            },
          },
        }),
      );

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('returns an error for a malformed API error response', () async {
      when(() => client.signUp(email: email, password: password))
          .thenAnswer((_) async => const Left({}));

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('returns an error when the API error list is empty', () async {
      when(() => client.signUp(email: email, password: password))
          .thenAnswer((_) async => const Left({'errors': []}));

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('returns an error when the client throws asynchronously', () async {
      when(() => client.signIn(email: email, password: password))
          .thenAnswer((_) async => throw Exception('network unavailable'));

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });
  });
}
