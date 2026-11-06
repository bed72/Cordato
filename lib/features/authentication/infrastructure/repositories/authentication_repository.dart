import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({required final PocketBase pocketBase})
    implements IAuthenticationRepository {
  @override
  Future<void> signOut() async {
    pocketBase.authStore.clear();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await pocketBase.collection('users').authWithPassword(email, password);
    } on ClientException catch (exception) {
      throw AuthenticationException(
        errors: PocketBaseMapper.fromException(exception),
      );
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      await pocketBase
          .collection('users')
          .create(
            body: {
              'email': email,
              'password': password,
              'passwordConfirm': password,
            },
          );
    } on ClientException catch (exception) {
      throw AuthenticationException(
        errors: PocketBaseMapper.fromException(exception),
      );
    }
  }

  @override
  Future<void> resendEmail({required String email}) async {
    try {
      await pocketBase.collection('users').requestVerification(email);
    } on ClientException catch (exception) {
      throw AuthenticationException(
        errors: PocketBaseMapper.fromException(exception),
      );
    }
  }

  @override
  Future<EmailVerificationStatusEnum> confirmEmail(String token) async {
    if (token.isEmpty) return .invalid;

    try {
      await pocketBase.collection('users').confirmVerification(token);

      return .success;
    } on ClientException catch (exception) {
      final errors = PocketBaseMapper.fromException(exception);

      return errors.errors.first.status == '400' ? .invalid : .failure;
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await pocketBase.collection('users').requestPasswordReset(email);
    } on ClientException catch (exception) {
      throw AuthenticationException(
        errors: PocketBaseMapper.fromException(exception),
      );
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      await pocketBase
          .collection('users')
          .confirmPasswordReset(token, password, passwordConfirm);
    } on ClientException catch (exception) {
      final errors = PocketBaseMapper.fromException(exception);

      if (exception.statusCode == 400 &&
          errors.errors.any((error) => error.pointer == '/token')) {
        throw PasswordResetTokenException(errors: errors);
      }

      throw AuthenticationException(errors: errors);
    }
  }

  @override
  Future<void> changePassword({
    required String password,
    required String oldPassword,
    required String passwordConfirm,
  }) async {
    final id = pocketBase.userId();

    try {
      await pocketBase
          .collection('users')
          .update(
            id,
            body: {
              'password': password,
              'oldPassword': oldPassword,
              'passwordConfirm': passwordConfirm,
            },
          );
    } on ClientException catch (exception) {
      throw AuthenticationException(
        errors: PocketBaseMapper.fromException(exception),
      );
    }
  }
}
