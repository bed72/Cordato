import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

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

  test('confirmation delegates the original URL to IHttpClient', () async {
    const url =
        'https://other.example/api/email-verification/12/abc?signature=123&expires=456';
    when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(HttpResponse(statusCode: 204, body: {})),
    );

    expect((await client.confirmEmail(url)).right.statusCode, 204);
    final request =
        verify(() => http.get(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, url);
    expect(request.route, isNull);
    expect(request.followRedirects, isFalse);
    expect(request.logRequest, isFalse);
  });

  test('sign-in posts a JSON:API access-tokens resource', () async {
    final payload = <String, dynamic>{
      'data': {'id': '2'},
    };
    when(() => http.post(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => Right(HttpResponse(statusCode: 200, body: payload)),
    );

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
    expect(response.right.body, same(payload));
    expect(request.path, 'authentication/sign-in');
    expect(request.route, HttpPathEnum.signIn);
    expect(request.body, {
      'data': {
        'type': 'access-tokens',
        'attributes': {'email': 'person@example.com', 'password': 'secret'},
      },
    });
  });

  test('sign-up sends Trocado as name and confirms the password', () async {
    final error = <String, dynamic>{
      'errors': [
        {'status': '422'},
      ],
    };
    when(
      () => http.post(parameter: any(named: 'parameter')),
    ).thenAnswer((_) async => Left(HttpResponse(statusCode: 422, body: error)));

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
    expect(response.left.body, same(error));
    expect(request.path, 'authentication/sign-up');
    expect(request.route, HttpPathEnum.signUp);
    expect(request.body, {
      'data': {
        'type': 'sign-ups',
        'attributes': {
          'name': 'Trocado',
          'password': 'secret',
          'email': 'gabriel@example.com',
          'password_confirmation': 'secret',
        },
      },
    });
  });

  test('resend posts the email-verifications JSON:API resource', () async {
    when(() => http.post(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Right(HttpResponse(statusCode: 202, body: {})),
    );

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
    expect(request.route, HttpPathEnum.resendEmailVerification);
    expect(request.body, {
      'data': {
        'type': 'email-verifications',
        'attributes': {'email': 'person@example.com'},
      },
    });
  });
}
