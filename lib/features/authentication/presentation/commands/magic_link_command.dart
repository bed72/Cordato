import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class MagicLinkCommand({
  required IAuthenticationRepository repository,
  DateTime Function()? now,
}) implements ICommand {
  String? _email;
  DateTime? _resendAvailableAt;

  final DateTime Function() _now = now ?? DateTime.now;
  final Command<String, void> send = _request(repository);
  final Command<String, void> resend = _request(repository);

  static const cooldown = Duration(minutes: 1);

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
        final response = await repository.requestMagicLink(email: email);
        response.fold((failure) => throw failure, (_) {});
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
