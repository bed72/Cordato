import 'dart:async';

import 'package:dio/dio.dart';

final class SessionClient({required final Dio client}) {
  Future<void> _pending = Future<void>.value();
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  Stream<bool> get sessionChanges => _changes.stream;

  Future<bool> loadSession() => _enqueue(() async {
    bool hasSession;
    try {
      await client.get<void>('/account');
      hasSession = true;
    } on DioException catch (exception) {
      if (!_isUnauthorized(exception)) rethrow;

      hasSession = false;
    }

    _changes.add(hasSession);
    return hasSession;
  });

  Future<void> confirmCode({required String userId, required String code}) =>
      _enqueue(() async {
        await client.post<void>(
          '/account/sessions/token',
          data: {'userId': userId, 'secret': code},
        );
        await client.get<void>('/account');
        _changes.add(true);
      });

  Future<void> signOut() => _enqueue(() async {
    try {
      await client.delete<void>('/account/sessions/current');
    } on DioException catch (exception) {
      if (!_isUnauthorized(exception)) rethrow;
    }

    _changes.add(false);
  });

  Future<void> close() async {
    await Future.wait([_pending, _changes.close()]);
  }

  bool _isUnauthorized(DioException exception) =>
      exception.type == .badResponse && exception.response?.statusCode == 401;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final pending = _pending.then((_) => operation());

    _pending = pending.then<void>((_) {}, onError: (_, _) {});

    return pending;
  }
}
