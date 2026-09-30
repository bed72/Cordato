import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/authentication/infrastructure/responses/sign_in_response.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({
  required final IAuthenticationDataSource _dataSource,
}) implements IAuthenticationRepository {
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
