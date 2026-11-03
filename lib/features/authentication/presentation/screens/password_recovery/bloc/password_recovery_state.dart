import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class PasswordRecoveryState {
  const PasswordRecoveryState();

  String? get sentEmail => switch (this) {
    PasswordRecoverySent(:final email) => email,
    PasswordRecoverySubmitting(:final previousEmail) => previousEmail,
    PasswordRecoveryFailure(:final previousEmail) => previousEmail,
    _ => null,
  };

  bool get isSubmitting => this is PasswordRecoverySubmitting;

  bool get canSubmit => switch (this) {
    PasswordRecoveryInitial() || PasswordRecoveryFailure() => true,
    PasswordRecoverySent(:final remaining) => remaining == Duration.zero,
    _ => false,
  };

  Duration get remaining => switch (this) {
    PasswordRecoverySent(remaining: final value) => value,
    _ => Duration.zero,
  };
}

final class const PasswordRecoveryInitial() extends PasswordRecoveryState {}

final class const PasswordRecoverySubmitting({final String? previousEmail})
    extends PasswordRecoveryState {}

final class const PasswordRecoverySent({
  required final String email,
  @override required final Duration remaining,
}) extends PasswordRecoveryState {}

final class const PasswordRecoveryFailure({
  required final ErrorsEntity errors,
  final String? previousEmail,
}) extends PasswordRecoveryState {}
