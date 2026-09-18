final class const UserEntity({final String? name, final String? email}) {
  String get nickname {
    final userName = name?.trim();
    if (userName != null && userName.isNotEmpty) return userName;

    final userEmail = email?.trim();
    if (userEmail != null && userEmail.isNotEmpty) {
      return userEmail.split('@').first;
    }

    return 'Usuário';
  }
}
