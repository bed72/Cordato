import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/remoto/authentication_remote_data_source.dart';

class _HttpClientMock extends Mock implements IHttpClient {}

void main() {
  const password = 'secret';
  const email = 'person@example.com';

  late IHttpClient client;
  late IAuthenticationRemoteDataSource dataSource;

  setUpAll(() => registerFallbackValue(const Requests('')));
  setUp(() {
    client = _HttpClientMock();
    dataSource = AuthenticationRemoteDataSource(client: client);
  });

  group('AuthenticationRemoteDataSource', () {
    test(
      'logout deletes the protected sign-out endpoint without a body',
      () async {
        when(() => client.delete(parameter: any(named: 'parameter')))
            .thenAnswer(
              (_) async => const Right(HttpResponse(statusCode: 204, body: {})),
            );

        expect((await dataSource.logout()).right, isTrue);
        final request =
            verify(
                  () =>
                      client.delete(parameter: captureAny(named: 'parameter')),
                ).captured.single
                as Requests;
        expect(request.path, 'authentication/sign-out');
        expect(request.route, HttpPathEnum.logout);
        expect(request.route?.requiresAuth, isTrue);
        expect(request.body, isNull);
        expect(request.headers, isNull);
        verifyNoMoreInteractions(client);
      },
    );

    test('logout preserves JSON API errors', () async {
      when(() => client.delete(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(
          HttpResponse(
            statusCode: 403,
            body: {
              'errors': [
                {
                  'status': '403',
                  'title': 'Não autorizado',
                  'detail': 'Conta bloqueada.',
                },
              ],
            },
          ),
        ),
      );

      final result = await dataSource.logout();
      expect(result.left.errors.single.status, '403');
      expect(result.left.errors.single.title, 'Não autorizado');
      expect(result.left.errors.single.detail, 'Conta bloqueada.');
    });

    test(
      'logout translates unexpected client exceptions to unknown errors',
      () async {
        when(() => client.delete(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => throw StateError('offline'));

        expect(
          (await dataSource.logout()).left.errors.single.title,
          'Erro desconhecido',
        );
      },
    );

    test(
      'logout translates malformed or empty API errors to unknown errors',
      () async {
        for (final body in <Map<String, dynamic>>[
          {},
          {'errors': []},
        ]) {
          when(() => client.delete(parameter: any(named: 'parameter')))
              .thenAnswer(
                (_) async => Left(HttpResponse(statusCode: 500, body: body)),
              );
          expect(
            (await dataSource.logout()).left.errors.single.title,
            'Erro desconhecido',
          );
        }
      },
    );

    test('logout preserves transport errors from the HTTP client', () async {
      when(() => client.delete(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(
          HttpResponse(
            statusCode: 0,
            body: {
              'errors': [
                {
                  'title': 'Erro desconhecido',
                  'detail': 'Não foi possível processar a resposta.',
                },
              ],
            },
          ),
        ),
      );

      expect(
        (await dataSource.logout()).left.errors.single.detail,
        'Não foi possível processar a resposta.',
      );
    });

    test('confirmation passes the original URL and status', () async {
      const url =
          'https://other.example/api/email-verification/12/abc?signature=123&expires=456';
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(HttpResponse(statusCode: 204, body: {})),
      );

      expect(await dataSource.confirmEmail(url), 204);
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, url);
      expect(request.route, isNull);
      expect(request.followRedirects, isFalse);
      expect(request.logRequest, isFalse);
    });

    test('confirmation returns null when the client fails', () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenThrow(StateError('offline'));

      expect(await dataSource.confirmEmail('signed'), isNull);
    });
    test('confirmation maps 403 and transport failure by status', () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(HttpResponse(statusCode: 403, body: {})),
      );
      expect(await dataSource.confirmEmail('signed'), 403);

      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(HttpResponse(statusCode: 0, body: {})),
      );
      expect(await dataSource.confirmEmail('signed'), isNull);
    });

    test('confirmation preserves an unexpected HTTP status', () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(HttpResponse(statusCode: 500, body: {})),
      );

      expect(await dataSource.confirmEmail('signed'), 500);
    });

    test('sign-in returns the parsed access token response', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(
          HttpResponse(
            statusCode: 200,
            body: {
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
            },
          ),
        ),
      );

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isRight, isTrue);
      expect(data.right.userId, '5');
      expect(data.right.token, 'example-token');
      expect(data.right.expiresAt, DateTime.utc(2026, 9, 28, 18, 30, 6));
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.headers, isNull);
      expect(request.path, 'authentication/sign-in');
      expect(request.route, HttpPathEnum.signIn);
      expect(request.body, {
        'data': {
          'type': 'access-tokens',
          'attributes': {'email': email, 'password': password},
        },
      });
    });

    test('sign-up returns the parsed registration response', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Right(
          HttpResponse(
            statusCode: 201,
            body: {
              'data': {'id': '3'},
            },
          ),
        ),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isRight, isTrue);
      expect(data.right.id, '3');
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.headers, isNull);
      expect(request.path, 'authentication/sign-up');
      expect(request.route, HttpPathEnum.signUp);
      expect(request.body, {
        'data': {
          'type': 'sign-ups',
          'attributes': {
            'email': email,
            'name': 'Trocado',
            'password': password,
            'password_confirmation': password,
          },
        },
      });
    });

    test('resend accepts a successful response without a body', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(HttpResponse(statusCode: 202, body: {})),
      );

      final data = await dataSource.resendEmail(email: email);

      expect(data.right, isTrue);
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'authentication/email-verification/resend');
      expect(request.route, HttpPathEnum.resendEmailVerification);
      expect(request.body, {
        'data': {
          'type': 'email-verifications',
          'attributes': {'email': email},
        },
      });
    });

    test('resend preserves API errors', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(
          HttpResponse(
            statusCode: 429,
            body: {
              'errors': [
                {'status': '429', 'detail': 'Aguarde antes de reenviar.'},
              ],
            },
          ),
        ),
      );

      final data = await dataSource.resendEmail(email: email);

      expect(data.left.errors.single.status, '429');
      expect(data.left.errors.single.detail, 'Aguarde antes de reenviar.');
    });

    test('resend handles transport exceptions', () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenThrow(StateError('network unavailable'));

      final data = await dataSource.resendEmail(email: email);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('preserves all API errors from a failed sign-in', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Left(
          HttpResponse(
            statusCode: 401,
            body: {
              'errors': [
                {
                  'status': '401',
                  'detail': 'Confira o e-mail.',
                  'title': 'Credenciais inválidas',
                  'source': {'pointer': '/data/attributes/email'},
                },
                {'detail': 'Confira a senha.', 'status': '401'},
              ],
            },
          ),
        ),
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
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => Left(
          HttpResponse(
            statusCode: 422,
            body: {
              'errors': [
                {'detail': 'E-mail já cadastrado.', 'status': '422'},
              ],
            },
          ),
        ),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, 'E-mail já cadastrado.');
    });

    test('returns an error for a malformed success response', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(HttpResponse(statusCode: 200, body: {})),
      );

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('rejects a malformed successful sign-up response', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(HttpResponse(statusCode: 201, body: {})),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.title, 'Erro desconhecido');
    });

    test('rejects a sign-in response without a user relationship', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Right(
          HttpResponse(
            statusCode: 200,
            body: {
              'data': {
                'id': '2',
                'attributes': {
                  'token': 'example-token',
                  'expires_at': '2026-09-28T18:30:06+00:00',
                },
              },
            },
          ),
        ),
      );

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('returns an error for a malformed API error response', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Left(HttpResponse(statusCode: 422, body: {})),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('returns an error when the API error list is empty', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async =>
            const Left(HttpResponse(statusCode: 422, body: {'errors': []})),
      );

      final data = await dataSource.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });

    test('resend maps an empty API error list to a generic error', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async =>
            const Left(HttpResponse(statusCode: 429, body: {'errors': []})),
      );

      final data = await dataSource.resendEmail(email: email);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.title, 'Erro desconhecido');
    });

    test('returns an error when the client throws asynchronously', () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => throw Exception('network unavailable'));

      final data = await dataSource.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, isNotEmpty);
    });
  });
}
