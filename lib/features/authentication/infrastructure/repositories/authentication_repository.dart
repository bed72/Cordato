import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/mappers/response_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({
  required final IHttpClient _httpClient,
  required final ISessionClient _sessionClient,
}) implements IAuthenticationRepository {
  @override
  Future<String> requestCode({required String email}) async {
    try {
      final response = await _httpClient.post(
        parameter: Requests(
          path: '/account/tokens/email',
          body: {'userId': 'unique()', 'email': email},
        ),
      );

      final userId = response.body['userId'] as String;
      if (userId.trim().isEmpty) {
        throw const FormatException('Identificador de usuário ausente');
      }

      return userId;
    } on HttpClientException catch (exception) {
      throw AuthenticationException(
        errors: ResponseMapper.fromException(exception),
      );
    }
  }

  @override
  Future<void> confirmCode({
    required String code,
    required String userId,
  }) async {
    try {
      await _sessionClient.confirmCode(userId: userId, code: code);
    } on HttpClientException catch (exception) {
      throw AuthenticationException(
        errors: ResponseMapper.fromException(exception),
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _sessionClient.signOut();
    } on HttpClientException catch (exception) {
      throw AuthenticationException(
        errors: ResponseMapper.fromException(exception),
      );
    }
  }
}
