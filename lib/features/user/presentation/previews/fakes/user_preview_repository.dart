import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserPreviewRepository({final bool rejectAvatar = false})
    implements IUserRepository {
  UserEntity _user = const UserEntity(
    id: 'preview-user',
    status: 'active',
    name: 'Gabriel Ramos',
    email: 'gabriel@exemplo.com',
  );

  @override
  Future<UserEntity> getById() async => _user;

  @override
  Future<void> delete() async => throw UserException(errors: .unknown());

  @override
  Future<UserEntity> update({String? name, String? avatar}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (rejectAvatar && avatar != null) {
      throw UserException(
        errors: const ErrorsEntity(
          errors: [
            ErrorEntity(detail: 'Não foi possível salvar. Tente novamente.'),
          ],
        ),
      );
    }
    _user = UserEntity(
      id: _user.id,
      email: _user.email,
      status: _user.status,
      name: name ?? _user.name,
      avatar: avatar ?? _user.avatar,
    );
    return _user;
  }
}
