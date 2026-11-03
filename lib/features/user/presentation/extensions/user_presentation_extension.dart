import 'package:cordato/features/user/domain/entities/user_entity.dart';

extension UserPresentationExtension on UserEntity {
  String get displayName => name.trim().isEmpty ? 'Trocado' : name;
}
