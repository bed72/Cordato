import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserPreviewRepository({final bool rejectAvatar = false})
    implements IUserRepository {
  UserEntity _user = const UserEntity(
    name: 'Gabriel Ramos',
    avatar: 'preview-avatar',
  );

  @override
  Future<UserEntity> get() async => _user;

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
      name: name ?? _user.name,
      avatar: avatar ?? _user.avatar,
    );
    return _user;
  }
}
