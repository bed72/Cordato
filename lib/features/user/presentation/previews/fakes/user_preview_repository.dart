import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class UserPreviewRepository({final bool rejectAvatar = false})
    implements IUserRepository {
  UserEntity _user = const UserEntity(
    id: 'preview-user',
    status: 'active',
    name: 'Gabriel Ramos',
    email: 'gabriel@exemplo.com',
  );

  @override
  Future<GetByIdRepositoryType> getById() async => Right(_user);

  @override
  Future<DeleteRepositoryType> delete() async => const Right(false);

  @override
  Future<UpdateRepositoryType> update({String? name, String? avatar}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (rejectAvatar && avatar != null) {
      return const Left(
        ErrorsEntity(
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
    return Right(_user);
  }
}
