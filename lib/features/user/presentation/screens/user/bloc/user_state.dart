import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';

sealed class UserState {
  const UserState();

  UserEntity? get user => switch (this) {
    UserReady(:final data) => data,
    UserDeleting(:final data) => data,
    UserAvatarSaving(:final data) => data,
    UserAvatarSuccess(:final data) => data,
    UserAvatarFailure(:final data) => data,
    UserDeleteFailure(:final data) => data,
    UserDeleteSuccess(:final data) => data,
    _ => null,
  };

  bool get canDelete => canLoad;
  bool get isLoading => this is UserLoading;
  bool get isDeleting => this is UserDeleting;
  bool get canEdit => canLoad && user != null;
  bool get isSavingAvatar => this is UserAvatarSaving;
  bool get canLoad => !isBusy && this is! UserDeleteSuccess;
  bool get isBusy => isLoading || isSavingAvatar || isDeleting;
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

final class const UserDeleting({required final UserEntity? data})
    extends UserState {}

final class const UserDeleteSuccess({required final UserEntity? data})
    extends UserState {}

final class const UserDeleteFailure({
  required final UserEntity? data,
  required final ErrorsEntity errors,
}) extends UserState {}
