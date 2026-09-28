import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';

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

    final result = await client.signIn(
      email: 'person@example.com',
      password: 'secret',
    );
    final request =
        verify(() => http.post(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;

    expect(request.path, '/api/authentication/sign-in');
    expect(request.headers, isNull);
    expect(request.body, {
      'data': {
        'type': 'access-tokens',
        'attributes': {'email': 'person@example.com', 'password': 'secret'},
      },
    });
    expect(result.right, same(payload));
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

      final result = await client.signUp(
        email: 'gabriel@example.com',
        password: 'secret',
      );
      final request =
          verify(() => http.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.path, '/api/authentication/sign-up');
      expect(request.headers, isNull);
      expect(request.body, {
        'data': {
          'type': 'sign-ups',
          'attributes': {
            'name': 'gabriel',
            'email': 'gabriel@example.com',
            'password': 'secret',
            'password_confirmation': 'secret',
          },
        },
      });
      expect(result.left, same(error));
    },
  );
}
