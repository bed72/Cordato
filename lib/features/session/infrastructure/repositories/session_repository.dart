import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/mappers/response_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

final class SessionRepository({required final ISessionClient _sessionClient})
    implements ISessionRepository {
  @override
  Stream<bool> get session => _sessionClient.session;

  @override
  Future<bool> loadSession() async {
    try {
      return await _sessionClient.loadSession();
    } on HttpClientException catch (exception) {
      throw SessionException(errors: ResponseMapper.fromException(exception));
    }
  }
}
