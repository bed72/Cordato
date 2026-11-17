import 'dart:async';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/application/clients/interface_session_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

final class SessionClient({required final IHttpClient _client})
    implements ISessionClient {
  Future<void> _pending = Future<void>.value();
  final _changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> get session => _changes.stream;

  @override
  Future<void> close() async {
    await Future.wait([_pending, _changes.close()]);
  }

  @override
  Future<void> signOut() => _enqueue(() async {
    try {
      await _client.delete(
        parameter: const Requests(path: '/account/sessions/current'),
      );
    } on HttpResponseException catch (exception) {
      if (exception.response.status != 401) rethrow;
    }

    _changes.add(false);
  });

  @override
  Future<void> confirmCode({required String userId, required String code}) =>
      _enqueue(() async {
        await _client.post(
          parameter: Requests(
            path: '/account/sessions/token',
            body: {'userId': userId, 'secret': code},
          ),
        );

        await _client.get(parameter: const Requests(path: '/account'));
        _changes.add(true);
      });

  @override
  Future<bool> loadSession() => _enqueue(() async {
    bool hasSession;
    try {
      await _client.get(parameter: const Requests(path: '/account'));
      hasSession = true;
    } on HttpResponseException catch (exception) {
      if (exception.response.status != 401) rethrow;

      hasSession = false;
    }

    _changes.add(hasSession);
    return hasSession;
  });

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final pending = _pending.then((_) => operation());

    _pending = pending.then<void>((_) {}, onError: (_, _) {});

    return pending;
  }
}
