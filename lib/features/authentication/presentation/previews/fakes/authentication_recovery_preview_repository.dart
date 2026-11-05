import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class const AuthenticationRecoveryPreviewRepository({
  final ErrorsEntity? changeErrors,
  final Future<void>? changeOperation,
  final bool failSignOut = false,
}) implements IAuthenticationRepository {
  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordConfirm,
  }) async {}

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('Preview: limpeza indisponível');
  }

  @override
  Future<void> changePassword({
    required String password,
    required String oldPassword,
    required String passwordConfirm,
  }) async {
    await changeOperation;
    if (changeErrors case final errors?) {
      throw AuthenticationException(errors: errors);
    }
  }

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
