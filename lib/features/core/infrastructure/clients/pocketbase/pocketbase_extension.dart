import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

extension PocketBaseExtension on PocketBase {
  bool get hasSession => authStore.token.isNotEmpty;

  String userId() {
    final id = authStore.record?.id;

    if (id == null || id.trim().isEmpty) {
      throw const MissingAuthenticatedUserException();
    }

    return id;
  }
}
