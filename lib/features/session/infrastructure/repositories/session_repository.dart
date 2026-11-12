import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

final class SessionRepository({required final PocketBase pocketBase})
    implements ISessionRepository {
  Future<bool>? _pending;
  String? _pendingToken;
  RecordModel? _pendingRecord;

  @override
  Stream<bool> get sessionChanges =>
      pocketBase.authStore.onChange.map((event) => event.token.isNotEmpty);

  @override
  Future<bool> loadSession() {
    if (_pending case final pending?
        when _pendingToken == pocketBase.authStore.token &&
            identical(_pendingRecord, pocketBase.authStore.record)) {
      return pending;
    }

    _pendingToken = pocketBase.authStore.token;
    _pendingRecord = pocketBase.authStore.record;
    late final Future<bool> refresh;
    refresh = _refresh().whenComplete(() {
      if (identical(_pending, refresh)) {
        _pending = null;
        _pendingToken = null;
        _pendingRecord = null;
      }
    });
    _pending = refresh;

    return refresh;
  }

  Future<bool> _refresh() async {
    if (!pocketBase.hasSession) return false;

    final token = pocketBase.authStore.token;
    final record = pocketBase.authStore.record;
    bool sessionChanged = false;
    final changes = pocketBase.authStore.onChange.listen((_) {
      sessionChanged = true;
    });

    bool isCurrentSession() =>
        !sessionChanged &&
        pocketBase.authStore.token == token &&
        identical(pocketBase.authStore.record, record);

    try {
      final response = await pocketBase.send<Map<String, dynamic>>(
        '/api/collections/users/auth-refresh',
        method: 'POST',
        headers: {'Authorization': token},
      );

      if (!isCurrentSession()) return pocketBase.hasSession;

      final authentication = RecordAuth.fromJson(response);
      pocketBase.authStore.save(authentication.token, authentication.record);

      return pocketBase.hasSession;
    } on ClientException catch (exception) {
      final errors = PocketBaseMapper.fromException(exception);
      if (!isCurrentSession()) return pocketBase.hasSession;

      if (exception.statusCode == 401) {
        pocketBase.authStore.clear();

        return false;
      }

      throw SessionException(errors: errors);
    } finally {
      await changes.cancel();
    }
  }
}
