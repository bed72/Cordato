import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class MagicLinkCommand implements ICommand {
  String? _email;
  DateTime? _resendAvailableAt;

  final DateTime Function() _now;
  final Command<String, void> send;
  final Command<String, void> resend;

  static const cooldown = Duration(minutes: 1);

  MagicLinkCommand({
    required IAuthenticationRepository repository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       send = _request(repository),
       resend = _request(repository);

  String? get email => _email;

  Duration get resendRemaining {
    final availableAt = _resendAvailableAt;
    if (availableAt == null) return .zero;

    final remaining = availableAt.difference(_now());
    return remaining.isNegative ? .zero : remaining;
  }

  bool get canResend => email != null && resendRemaining == .zero;

  static Command<String, void> _request(IAuthenticationRepository repository) =>
      Command.createAsyncNoResult<String>((email) async {
        final data = await repository.requestMagicLink(email: email);
        data.fold((failure) => throw failure, (_) {});
      });

  void beginConfirmation(String email) {
    _email = email;
    _resendAvailableAt = _now().add(cooldown);
  }

  void startCooldown() {
    _resendAvailableAt = _now().add(cooldown);
  }

  @override
  void dispose() {
    send.dispose();
    resend.dispose();
  }
}
