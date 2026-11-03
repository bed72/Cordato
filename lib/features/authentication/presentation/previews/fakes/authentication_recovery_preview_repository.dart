import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class const AuthenticationRecoveryPreviewRepository()
    implements IAuthenticationRepository {
  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordConfirm,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resendEmail({required String email}) async =>
      throw UnsupportedError('Preview de recuperação');

  @override
  Future<EmailVerificationStatusEnum> confirmEmail(String token) async =>
      throw UnsupportedError('Preview de recuperação');

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => throw UnsupportedError('Preview de recuperação');

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async => throw UnsupportedError('Preview de recuperação');
}
