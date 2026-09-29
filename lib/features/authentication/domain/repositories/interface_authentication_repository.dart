import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

abstract interface class IAuthenticationRepository {
  Future<Either<ErrorsEntity, SessionEntity>> signIn({
    required String email,
    required String password,
  });
  Future<Either<ErrorsEntity, bool>> signUp({
    required String email,
    required String password,
  });
}
