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
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({
  required final IHttpClient _httpClient,
  required final IStorageClient _storageClient,
}) implements IAuthenticationRepository {
  @override
  Future<void> logout() async {
    try {
      await _httpClient.delete(
        parameter: Requests(path: HttpPathEnum.logout.path),
      );

      await _storageClient.clear();
    } on HttpResponseException catch (exception) {
      throw AuthenticationException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }

  @override
  Future<EmailVerificationStatusEnum> confirmEmail(String url) async {
    if (url.isEmpty) return .invalid;

    try {
      final response = await _httpClient.get(parameter: Requests(path: url));

      return switch (response.status) {
        204 => .success,
        403 => .invalid,
        _ => .failure,
      };
    } on HttpResponseException catch (exception) {
      return exception.status == 403 ? .invalid : .failure;
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
          body: {
            'data': {
              'type': 'email-verifications',
              'attributes': {'email': email},
            },
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
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _httpClient.post(
        parameter: Requests(
          path: HttpPathEnum.signUp.path,
          body: {
            'data': {
              'type': 'sign-ups',
              'attributes': {
                'email': email,
                'name': 'Trocado',
                'password': password,
                'password_confirmation': password,
              },
            },
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
          body: {
            'data': {
              'type': 'access-tokens',
              'attributes': {'email': email, 'password': password},
            },
          },
        ),
      );

      final data = SignInResponse.fromJson(response.body);

      await Future.wait([
        _storageClient.write(
          value: data.userId,
          key: StorageKeyEnum.userId.key,
        ),
        _storageClient.write(
          value: data.token,
          key: StorageKeyEnum.opaqueToken.key,
        ),
      ]);
    } on HttpResponseException catch (exception) {
      throw AuthenticationException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw AuthenticationException(errors: .unknown());
    }
  }
}
