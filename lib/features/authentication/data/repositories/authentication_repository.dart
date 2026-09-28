import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class AuthenticationRepository({
  required final IAuthenticationDataSource _dataSource,
}) implements IAuthenticationRepository {
  @override
  Future<bool> signIn({required String email, required String password}) {
    // TODO: implement signIn
    throw UnimplementedError();
  }

  @override
  Future<bool> signUp({required String email, required String password}) {
    // TODO: implement signUp
    throw UnimplementedError();
  }
}
