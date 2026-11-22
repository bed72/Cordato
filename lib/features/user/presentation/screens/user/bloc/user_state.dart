import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';

sealed class UserState {
  const UserState();

  bool get canLoad => !isBusy;
  bool get isLoading => this is UserLoading;
  bool get canEdit => canLoad && user != null;
  bool get isBusy => isLoading || isSavingAvatar;
  bool get isSavingAvatar => this is UserAvatarSaving;

  UserEntity? get user => switch (this) {
    UserReady(:final data) => data,
    UserAvatarSaving(:final data) => data,
    UserAvatarSuccess(:final data) => data,
    UserAvatarFailure(:final data) => data,
    _ => null,
  };
}

final class const UserInitial() extends UserState {}

final class const UserLoading() extends UserState {}

final class const UserReady({required final UserEntity data})
    extends UserState {}

final class const UserFailure({required final ErrorsEntity errors})
    extends UserState {}

final class const UserAvatarSaving({required final UserEntity data})
    extends UserState {}

final class const UserAvatarSuccess({required final UserEntity data})
    extends UserState {}

final class const UserAvatarFailure({
  required final UserEntity data,
  required final ErrorsEntity errors,
}) extends UserState {}
