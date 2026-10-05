import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/responses/sign_up_response.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_remote_data_source.dart';
import 'package:cordato/features/authentication/infrastructure/local/authentication_local_data_source.dart';

class _AuthenticationDataSourceMock extends Mock
    implements IAuthenticationRemoteDataSource {}

class _AuthenticationLocalDataSourceMock extends Mock
    implements IAuthenticationLocalDataSource {}

void main() {
  const password = 'secret';
  const email = 'person@example.com';

  late AuthenticationRepository repository;
  late IAuthenticationRemoteDataSource dataSource;
  late _AuthenticationLocalDataSourceMock localDataSource;

  setUp(() {
    dataSource = _AuthenticationDataSourceMock();
    localDataSource = _AuthenticationLocalDataSourceMock();
    when(() => localDataSource.save(any())).thenAnswer((_) async {});
    repository = AuthenticationRepository(
      remoteDataSource: dataSource,
      localDataSource: localDataSource,
    );
  });

  group('AuthenticationRepository', () {
    group('logout', () {
      setUp(() {
        when(() => dataSource.logout())
            .thenAnswer((_) async => const Right(true));
        when(() => localDataSource.remove()).thenAnswer((_) async {});
      });

      test('revokes remotely before removing the local token and returning success', () async {
        final result = await repository.logout();

        expect(result.right, isTrue);
        verifyInOrder([
          () => dataSource.logout(),
          () => localDataSource.remove(),
        ]);
        verifyNoMoreInteractions(dataSource);
        verifyNoMoreInteractions(localDataSource);
      });

      test(
        'preserves remote errors without removing the local token',
        () async {
          when(() => dataSource.logout()).thenAnswer(
            (_) async => const Left(
              ErrorsResponse(
                errors: [
                  ErrorResponse(
                    status: '403',
                    title: 'Não autorizado',
                    detail: 'Conta bloqueada.',
                  ),
                  ErrorResponse(
                    status: '403',
                    detail: 'Entre em contato com o suporte.',
                  ),
                ],
              ),
            ),
          );

          final result = await repository.logout();

          expect(result.left.errors, hasLength(2));
          expect(result.left.errors.first.status, '403');
          expect(result.left.errors.first.title, 'Não autorizado');
          expect(result.left.errors.first.detail, 'Conta bloqueada.');
          expect(
            result.left.errors.last.detail,
            'Entre em contato com o suporte.',
          );
          verifyZeroInteractions(localDataSource);
        },
      );

      test(
        'does not remove the token when remote logout is not accepted',
        () async {
          when(() => dataSource.logout())
              .thenAnswer((_) async => const Right(false));

          expect((await repository.logout()).right, isFalse);
          verifyZeroInteractions(localDataSource);
        },
      );

      test('converts unexpected remote exceptions without removing the local token', () async {
        when(() => dataSource.logout())
            .thenAnswer((_) async => throw StateError('offline'));

        expect(
          (await repository.logout()).left.errors.single.title,
          'Erro desconhecido',
        );
        verifyZeroInteractions(localDataSource);
      });

      test('returns an unknown error if local token removal fails', () async {
        when(() => localDataSource.remove())
            .thenAnswer((_) async => throw StateError('storage unavailable'));

        expect(
          (await repository.logout()).left.errors.single.title,
          'Erro desconhecido',
        );
        verify(() => dataSource.logout()).called(1);
        verify(() => localDataSource.remove()).called(1);
      });

      test('waits for revocation before removing the token', () async {
        final revoked = Completer<LogoutDataSourceType>();
        when(() => dataSource.logout()).thenAnswer((_) => revoked.future);

        final result = repository.logout();
        verifyZeroInteractions(localDataSource);
        revoked.complete(const Right(true));

        expect((await result).right, isTrue);
        verify(() => localDataSource.remove()).called(1);
      });

      test('only succeeds after local token removal completes', () async {
        final removed = Completer<void>();
        final removing = Completer<void>();
        when(() => localDataSource.remove()).thenAnswer((_) {
          removing.complete();
          return removed.future;
        });

        var completed = false;
        final result = repository.logout()..then((_) => completed = true);
        await removing.future;
        expect(completed, isFalse);
        removed.complete();

        expect((await result).right, isTrue);
        expect(completed, isTrue);
      });
    });

    const signed =
        'https://api.cordato.cloud/api/email-verification/12/abc123?signature=abcdef012345&expires=123456';

    test('rejects empty links without any request', () async {
      expect(
        await repository.confirmEmail(''),
        EmailVerificationStatusEnum.invalid,
      );
      verifyZeroInteractions(dataSource);
    });

    test('forwards the URL without validating its contents', () async {
      final otherHost = signed.replaceFirst(
        'api.cordato.cloud',
        'other.example',
      );
      when(() => dataSource.confirmEmail(otherHost))
          .thenAnswer((_) async => 204);

      expect(
        await repository.confirmEmail(otherHost),
        EmailVerificationStatusEnum.success,
      );
      verify(() => dataSource.confirmEmail(otherHost)).called(1);
    });

    test('maps confirmation HTTP statuses and connectivity', () async {
      for (final (status, expected) in [
        (204, EmailVerificationStatusEnum.success),
        (403, EmailVerificationStatusEnum.invalid),
        (500, EmailVerificationStatusEnum.failure),
        (null, EmailVerificationStatusEnum.failure),
      ]) {
        when(() => dataSource.confirmEmail(signed))
            .thenAnswer((_) async => status);
        expect(await repository.confirmEmail(signed), expected);
      }
      verify(() => dataSource.confirmEmail(signed)).called(4);
    });

    test(
      'maps an unexpected confirmation exception to connection failure',
      () async {
        when(() => dataSource.confirmEmail(signed))
            .thenAnswer((_) async => throw StateError('offline'));

        expect(
          await repository.confirmEmail(signed),
          EmailVerificationStatusEnum.failure,
        );
      },
    );

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
      verify(() => localDataSource.save('example-token')).called(1);
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
      verifyNever(() => localDataSource.save(any()));
    });

    test('sign-in fails if the token cannot be saved', () async {
      when(() => dataSource.signIn(email: email, password: password))
          .thenAnswer(
            (_) async => Right(
              SignInResponse(
                userId: 'user-1',
                token: 'example-token',
                expiresAt: DateTime.utc(2026, 11),
              ),
            ),
          );
      when(() => localDataSource.save('example-token'))
          .thenThrow(StateError('storage unavailable'));

      final data = await repository.signIn(email: email, password: password);

      expect(data.isLeft, isTrue);
      expect(data.left.errors.single.title, 'Erro desconhecido');
    });

    test('sign-in only succeeds after the token has been saved', () async {
      final saved = Completer<void>();
      final saving = Completer<void>();
      when(() => dataSource.signIn(email: email, password: password))
          .thenAnswer(
            (_) async => Right(
              SignInResponse(
                userId: 'user-1',
                token: 'opaque-token',
                expiresAt: DateTime.utc(2026, 11),
              ),
            ),
          );
      when(() => localDataSource.save('opaque-token')).thenAnswer((_) {
        saving.complete();
        return saved.future;
      });

      var completed = false;
      final signIn = repository.signIn(email: email, password: password)
        ..then((_) => completed = true);
      await saving.future;
      expect(completed, isFalse);

      saved.complete();
      expect((await signIn).right.token, 'opaque-token');
      expect(completed, isTrue);
    });

    test('sign-up returns true when registration succeeds', () async {
      when(() => dataSource.signUp(email: email, password: password))
          .thenAnswer((_) async => const Right(SignUpResponse(id: 'user-1')));

      final data = await repository.signUp(email: email, password: password);

      expect(data.right, isTrue);
      verify(() => dataSource.signUp(email: email, password: password))
          .called(1);
      verifyNever(() => localDataSource.save(any()));
    });

    test('resend returns success after acceptance', () async {
      when(() => dataSource.resendEmail(email: email))
          .thenAnswer((_) async => const Right(true));

      final data = await repository.resendEmail(email: email);

      expect(data.right, isTrue);
      verify(() => dataSource.resendEmail(email: email)).called(1);
      verifyNever(() => localDataSource.save(any()));
    });

    test(
      'resend forwards a non-accepted result without creating a session',
      () async {
        when(() => dataSource.resendEmail(email: email))
            .thenAnswer((_) async => const Right(false));

        final data = await repository.resendEmail(email: email);

        expect(data.right, isFalse);
        verifyNever(() => localDataSource.save(any()));
      },
    );

    test('resend preserves API errors as domain errors', () async {
      when(() => dataSource.resendEmail(email: email)).thenAnswer(
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

      final data = await repository.resendEmail(email: email);

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

    test(
      'sign-up and resend translate unexpected failures to domain errors',
      () async {
        when(() => dataSource.signUp(email: email, password: password))
            .thenAnswer((_) async => throw StateError('offline'));
        when(() => dataSource.resendEmail(email: email))
            .thenAnswer((_) async => throw StateError('offline'));

        final signUp = await repository.signUp(
          email: email,
          password: password,
        );
        final resend = await repository.resendEmail(email: email);

        expect(signUp.left.errors.single.title, 'Erro desconhecido');
        expect(resend.left.errors.single.title, 'Erro desconhecido');
        verifyNever(() => localDataSource.save(any()));
      },
    );
  });
}
