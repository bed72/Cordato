import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';

abstract interface class IUserClient {
  Future<UserEntity?> getUser();
}

final class const SupabaseUserClient({required final SupabaseClient _client})
    implements IUserClient {
  @override
  Future<UserEntity?> getUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata;
    final name =
        metadata?['name'] ??
        metadata?['full_name'] ??
        metadata?['display_name'];

    return UserEntity(name: name is String ? name : null, email: user.email);
  }
}
