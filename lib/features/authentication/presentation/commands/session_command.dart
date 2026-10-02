import 'dart:async';

import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class SessionCommand implements ICommand {
  SessionCommand({required IAuthenticationRepository repository}) {
    _subscription = repository.hasSession().listen(execute.run);
  }

  final Command<bool, bool?> execute = Command.createSync<bool, bool?>(
    (hasSession) => hasSession,
    initialValue: null,
  );

  late final StreamSubscription<bool> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    execute.dispose();
  }
}
