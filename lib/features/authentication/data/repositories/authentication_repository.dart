import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/enums/email_verification_status_enum.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/domain/value_objects/email_verification_url_value_object.dart';
import 'package:cordato/features/authentication/infrastructure/clients/email_verification_client.dart';

final class AuthenticationRepository({
  required final IAuthenticationDataSource _dataSource,
  required final IEmailVerificationClient verificationClient,
  required final String apiBaseUrl,
}) implements IAuthenticationRepository {
  @override
  Future<EmailVerificationStatusEnum> confirm(String? verificationUrl) async {
    final url = EmailVerificationUrlValueObject.tryParse(
      verificationUrl,
      baseUrl: apiBaseUrl,
    );
    if (url == null) {
      return EmailVerificationStatusEnum.invalidLink;
    }

    try {
      // Pass the original signed string verbatim; never rebuild its query.
      final status = await verificationClient.confirm(url.value);
      return switch (status) {
        204 => EmailVerificationStatusEnum.success,
        403 => EmailVerificationStatusEnum.invalidLink,
        _ => EmailVerificationStatusEnum.connectionFailure,
      };
    } catch (_) {
      return EmailVerificationStatusEnum.connectionFailure;
    }
  }

  @override
  Future<Either<ErrorsEntity, SessionEntity>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _dataSource.signIn(email: email, password: password);

      return data.either(
        (errors) => errors.toEntity(),
        (response) => response.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<Either<ErrorsEntity, bool>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _dataSource.signUp(email: email, password: password);

      return data.either((errors) => errors.toEntity(), (_) => true);
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<Either<ErrorsEntity, bool>> resendEmailVerification({
    required String email,
  }) async {
    try {
      final data = await _dataSource.resendEmailVerification(email: email);
      return data.either((errors) => errors.toEntity(), (success) => success);
    } catch (_) {
      return Left(.unknown());
    }
  }
}
