import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/dashboard/infrastructure/remoto/user_data_source.dart';

final class const UserRepository({required final IUserDataSource _dataSource})
    implements IUserRepository {
  @override
  Future<String?> getUserName() async {
    final user = await _dataSource.getUser();
    return user?.nickname;
  }
}
