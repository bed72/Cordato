import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/dashboard/infrastructure/remoto/user_data_source.dart';

final class UserRepository implements IUserRepository {
  final IUserDataSource _dataSource;

  const UserRepository({required this._dataSource});

  @override
  Future<String?> getUserName() async {
    final user = await _dataSource.getUser();
    return user?.nickname;
  }
}
