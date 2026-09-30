import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

class _AuthenticationDataSourceMock extends Mock
    implements IAuthenticationDataSource {}

void main() {
  const password = 'secret';
  const email = 'person@example.com';

  late AuthenticationRepository repository;
  late IAuthenticationDataSource dataSource;

  setUp(() {
    dataSource = _AuthenticationDataSourceMock();
    repository = AuthenticationRepository(dataSource: dataSource);
  });

  group('AuthenticationRepository', () {
    test('sign-in returns a session with the response data', () async {
      final expiresAt = DateTime.utc(2026, 9, 28, 18, 30);
      when(() => dataSource.signIn(email: email, password: password))
          .thenAnswer(
            (_) async => Right(
              SignInResponse(
                userId: 'user-1',
                expiresAt: expiresAt,
                token: 'example-token',
              ),
            ),
          );

      final data = await repository.signIn(email: email, password: password);

      expect(data.isRight, isTrue);
      expect(data.right.userId, 'user-1');
      expect(data.right.expiresAt, expiresAt);
      expect(data.right.token, 'example-token');
      verify(() => dataSource.signIn(email: email, password: password))
          .called(1);
    });

    test('sign-in preserves every API error and its metadata', () async {
      when(() => dataSource.signIn(email: email, password: password))
          .thenAnswer(
            (_) async => const Left(
              ErrorsResponse(
                errors: [
                  ErrorResponse(
                    status: '422',
                    title: 'Não autorizado',
                    detail: 'E-mail inválido.',
                    pointer: '/data/attributes/email',
                  ),
                  ErrorResponse(
                    status: '422',
                    detail: 'Senha inválida.',
                    pointer: '/data/attributes/password',
                  ),
                ],
              ),
            ),
          );

      final data = await repository.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors, hasLength(2));
      expect(data.left.errors.first.status, '422');
      expect(data.left.errors.first.title, 'Não autorizado');
      expect(data.left.errors.last.detail, 'Senha inválida.');
      expect(data.left.errors.first.detail, 'E-mail inválido.');
      expect(data.left.errors.first.pointer, '/data/attributes/email');
      expect(data.left.errors.last.pointer, '/data/attributes/password');
    });

    test('sign-up returns true when registration succeeds', () async {
      when(
        () => dataSource.signUp(email: email, password: password),
      ).thenAnswer((_) async => const Right(SignUpResponse(userId: 'user-1')));

      final data = await repository.signUp(email: email, password: password);

      expect(data.right, isTrue);
      verify(() => dataSource.signUp(email: email, password: password))
          .called(1);
    });

    test('resend returns success after acceptance', () async {
      when(() => dataSource.resendEmailVerification(email: email))
          .thenAnswer((_) async => const Right(true));

      final data = await repository.resendEmailVerification(email: email);

      expect(data.right, isTrue);
      verify(() => dataSource.resendEmailVerification(email: email)).called(1);
    });

    test('resend preserves API errors as domain errors', () async {
      when(() => dataSource.resendEmailVerification(email: email)).thenAnswer(
        (_) async => const Left(
          ErrorsResponse(
            errors: [
              ErrorResponse(
                status: '429',
                detail: 'Aguarde antes de reenviar.',
              ),
            ],
          ),
        ),
      );

      final data = await repository.resendEmailVerification(email: email);

      expect(data.left.errors.single.status, '429');
      expect(data.left.errors.single.detail, 'Aguarde antes de reenviar.');
    });

    test('sign-up returns the API errors as domain data', () async {
      when(() => dataSource.signUp(email: email, password: password))
          .thenAnswer(
            (_) async => const Left(
              ErrorsResponse(
                errors: [ErrorResponse(detail: 'E-mail já cadastrado.')],
              ),
            ),
          );

      final data = await repository.signUp(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.detail, 'E-mail já cadastrado.');
    });

    test(
      'sign-up returns an unknown error when the API error list is empty',
      () async {
        when(() => dataSource.signUp(email: email, password: password))
            .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

        final data = await repository.signUp(email: email, password: password);

        expect(data.left.errors, hasLength(1));
        expect(
          data.left.errors.single.detail,
          'Não foi possível processar a resposta.',
        );
      },
    );

    test('unexpected data source errors return a domain error', () async {
      when(() => dataSource.signIn(email: email, password: password))
          .thenThrow(StateError('transport error'));

      final data = await repository.signIn(email: email, password: password);

      expect(
        data.left.errors.single.detail,
        'Não foi possível processar a resposta.',
      );
    });
  });
}
