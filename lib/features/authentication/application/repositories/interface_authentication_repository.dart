import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';

abstract interface class IAuthenticationRepository {
  Future<void> logout();

  Future<void> resendEmail({required String email});

  Future<EmailVerificationStatusEnum> confirmEmail(String url);

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});
}
