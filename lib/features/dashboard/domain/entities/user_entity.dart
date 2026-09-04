final class UserEntity {
  final String? name;
  final String? email;

  const UserEntity({this.name, this.email});

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
