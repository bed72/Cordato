import 'dart:async';

import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/session/domain/repositories/interface_session_repository.dart';

final class SessionCommand implements ICommand {
  final ISessionRepository _repository;
  late final StreamSubscription<bool> _subscription;

  int _revision = 0;

  SessionCommand({required ISessionRepository repository})
    : _repository = repository {
    _subscription = repository.sessionChanges.listen((hasSession) {
      _revision++;
      execute.run(hasSession);
    });
  }

  final Command<bool, bool?> execute = Command.createSync<bool, bool?>(
    (hasSession) => hasSession,
    initialValue: null,
  );

  Future<void> loadSession() async {
    final revision = _revision;
    final hasSession = await _repository.loadSession();
    if (revision == _revision) execute.run(hasSession);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    execute.dispose();
  }
}
