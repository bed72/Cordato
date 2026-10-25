import 'package:cordato/features/user/domain/entities/user_entity.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class EditState {
  const EditState();

  bool get isSubmitting => this is EditSubmitting;

  bool get canSubmit => this is EditInitial || this is EditFailure;
}

final class const EditInitial() extends EditState {}

final class const EditSubmitting() extends EditState {}

final class const EditSuccess({required final UserEntity user})
    extends EditState {}

final class const EditFailure({required final ErrorsEntity errors})
    extends EditState {}
