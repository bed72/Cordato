import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserPreviewRepository({final bool rejectAvatar = false})
    implements IUserRepository {
  UserEntity _user = const UserEntity(
    id: 1,
    name: 'Gabriel Ramos',
    seed: 'preview-avatar',
  );

  @override
  Future<UserEntity> get() async => _user;

  @override
  Future<UserEntity> update({String? name, String? seed}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (rejectAvatar && seed != null) {
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
      name: name ?? _user.name,
      seed: seed ?? _user.seed,
    );
    return _user;
  }
}
