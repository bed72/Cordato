import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/email_cooldown.dart';

sealed class ResendEmailState {
  const ResendEmailState();

  bool get isSubmitting => this is ResendEmailSubmitting;

  bool get canSubmit => this is ResendEmailReady || this is ResendEmailFailure;

  Duration get remaining => switch (this) {
    ResendEmailSuccess() => EmailCooldown.duration,
    ResendEmailCooldown(:final timeLeft) => timeLeft,
    _ => Duration.zero,
  };
}

final class const ResendEmailInitial() extends ResendEmailState {}

final class const ResendEmailSuccess({final bool isInitialRequest = false})
    extends ResendEmailState {}

final class const ResendEmailCooldown({required final Duration timeLeft})
    extends ResendEmailState {}

final class const ResendEmailReady() extends ResendEmailState {}

final class const ResendEmailSubmitting() extends ResendEmailState {}

final class const ResendEmailFailure({
  required final ErrorsEntity errors,
  final bool isInitialRequest = false,
}) extends ResendEmailState {}
