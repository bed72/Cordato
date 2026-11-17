import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class AuthenticationPreviewRepository({
  final ErrorsEntity? requestFailure,
  final ErrorsEntity? confirmationFailure,
  final Future<String>? requestOperation,
  final Future<void>? confirmationOperation,
}) implements IAuthenticationRepository {
  int _requests = 0;

  @override
  Future<String> requestCode({required String email}) async {
    if (requestFailure case final failure?) {
      throw AuthenticationException(errors: failure);
    }
    return requestOperation ?? Future.value('preview-user-${++_requests}');
  }

  @override
  Future<void> confirmCode({
    required String userId,
    required String code,
  }) async {
    if (confirmationFailure case final failure?) {
      throw AuthenticationException(errors: failure);
    }
    await confirmationOperation;
  }

  @override
  Future<void> signOut() async {}
}
