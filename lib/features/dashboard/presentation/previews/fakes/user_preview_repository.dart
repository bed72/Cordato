import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';

final class UserPreviewRepository implements IUserRepository {
  const UserPreviewRepository();

  @override
  Future<String?> getUserName() async => 'Gabriel';
}
