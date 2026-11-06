import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

final class SessionRepository({required final PocketBase pocketBase})
    implements ISessionRepository {
  Future<bool>? _pending;

  @override
  Stream<bool> get sessionChanges =>
      pocketBase.authStore.onChange.map((event) => event.token.isNotEmpty);

  @override
  Future<bool> loadSession() =>
      _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<bool> _refresh() async {
    if (!pocketBase.hasSession) return false;

    try {
      await pocketBase.collection('users').authRefresh();

      return pocketBase.hasSession;
    } on ClientException catch (exception) {
      if (exception.statusCode == 401) {
        pocketBase.authStore.clear();

        return false;
      }

      throw SessionException(errors: PocketBaseMapper.fromException(exception));
    }
  }
}
