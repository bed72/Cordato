import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class DashboardUserPreviewRepository({final ErrorsEntity? failure})
    implements IUserRepository {
  @override
  Future<UserEntity> get() async {
    if (failure != null) {
      throw UserException(errors: failure!);
    }
    return const UserEntity(name: 'Gabriel', avatar: 'preview-avatar');
  }

  @override
  Future<UserEntity> update({String? name, String? avatar}) async =>
      throw UserException(errors: .unknown());
}
