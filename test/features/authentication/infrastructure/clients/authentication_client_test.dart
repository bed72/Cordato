import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';

import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';

class _HttpClientMock extends Mock implements IHttpClient {}

void main() {
  late _HttpClientMock http;
  late AuthenticationClient client;

  setUpAll(() => registerFallbackValue(const Requests('')));
  setUp(() {
    http = _HttpClientMock();
    client = AuthenticationClient(client: http);
  });

  test('sign-in posts a JSON:API access-tokens resource', () async {
    final payload = <String, dynamic>{
      'data': {'id': '2'},
    };
    when(() => http.post(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => Right(payload));

    final response = await client.signIn(
      password: 'secret',
      email: 'person@example.com',
    );
    final request =
        verify(() => http.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(request.headers, isNull);
    expect(response.right, same(payload));
    expect(request.path, 'authentication/sign-in');
    expect(request.body, {
      'data': {
        'type': 'access-tokens',
        'attributes': {'email': 'person@example.com', 'password': 'secret'},
      },
    });
  });

  test(
    'sign-up derives name and confirmation from email and password',
    () async {
      final error = <String, dynamic>{
        'errors': [
          {'status': '422'},
        ],
      };
      when(() => http.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => Left(error));

      final response = await client.signUp(
        password: 'secret',
        email: 'gabriel@example.com',
      );

      final request =
          verify(() => http.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.headers, isNull);
      expect(response.left, same(error));
      expect(request.path, 'authentication/sign-up');
      expect(request.body, {
        'data': {
          'type': 'sign-ups',
          'attributes': {
            'name': 'gabriel',
            'password': 'secret',
            'email': 'gabriel@example.com',
            'password_confirmation': 'secret',
          },
        },
      });
    },
  );

  test('resend posts the email-verifications JSON:API resource', () async {
    when(() => http.post(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Right({}));

    final response = await client.resendEmailVerification(
      email: 'person@example.com',
    );
    final request =
        verify(() => http.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(response.isRight, isTrue);
    expect(request.path, 'authentication/email-verification/resend');
    expect(request.body, {
      'data': {
        'type': 'email-verifications',
        'attributes': {'email': 'person@example.com'},
      },
    });
  });
}
