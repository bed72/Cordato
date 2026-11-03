import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({
  required final IHttpClient _httpClient,
  required final IStorageClient _storageClient,
}) implements IAuthenticationRepository {
  @override
  Future<void> signOut() async {
    await _storageClient.clear();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      final response = await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.requestPasswordReset.path,
          body: {'email': email},
        ),
      );

      if (response.status != 204) {
        throw AuthenticationException(errors: .unknown());
      }
    } on HttpResponseException catch (exception) {
      throw AuthenticationException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.confirmPasswordReset.path,
          body: {
            'token': token,
            'password': password,
            'passwordConfirm': passwordConfirm,
          },
        ),
      );
      if (response.status != 204) {
        throw AuthenticationException(errors: .unknown());
      }
    } on HttpResponseException catch (exception) {
      final errors = exception.errors.toEntity();
      if (exception.status == 400 &&
          errors.errors.any((error) => error.pointer == '/token')) {
        throw PasswordResetTokenException(errors: errors);
      }
      throw AuthenticationException(errors: errors);
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }

  @override
  Future<EmailVerificationStatusEnum> confirmEmail(String token) async {
    if (token.isEmpty) return .invalid;

    try {
      final response = await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.confirmEmailVerification.path,
          body: {'token': token},
        ),
      );

      return switch (response.status) {
        204 => .success,
        _ => .failure,
      };
    } on HttpResponseException catch (exception) {
      return exception.status == 400 ? .invalid : .failure;
    } on HttpClientException {
      return .failure;
    }
  }

  @override
  Future<void> resendEmail({required String email}) async {
    try {
      await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.resendEmailVerification.path,
          body: {'email': email},
        ),
      );
    } on HttpResponseException catch (exception) {
      throw AuthenticationException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.signUp.path,
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
          },
        ),
      );
    } on HttpResponseException catch (exception) {
      throw AuthenticationException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final response = await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.signIn.path,
          body: {'identity': email, 'password': password},
        ),
      );

      final data = SignInResponse.fromJson(response.body);

      await Future.wait([
        _storageClient.write(
          value: data.userId,
          key: StorageKeyEnum.userId.key,
        ),
        _storageClient.write(value: data.token, key: StorageKeyEnum.token.key),
      ]);
    } on HttpResponseException catch (exception) {
      throw AuthenticationException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }
}
