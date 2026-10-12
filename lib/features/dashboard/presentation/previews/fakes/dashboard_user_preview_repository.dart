import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class DashboardUserPreviewRepository implements IUserRepository {
  @override
  Future<GetByIdRepositoryType> getById() async => const Right(
    UserEntity(
      name: 'Gabriel',
      status: 'active',
      id: 'preview-user',
      email: 'preview@example.com',
    ),
  );

  @override
  Future<DeleteRepositoryType> delete() async => Left(.unknown());

  @override
  Future<UpdateRepositoryType> update({String? name}) async => Left(.unknown());
}
