import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';

abstract interface class IAuthenticationRepository {
  Future<void> signOut();

  Future<void> resendEmail({required String email});

  Future<void> requestPasswordReset({required String email});

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordConfirm,
  });

  Future<EmailVerificationStatusEnum> confirmEmail(String token);

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});
}
