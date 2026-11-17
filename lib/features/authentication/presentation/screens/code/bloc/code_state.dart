import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class CodeState {
  const CodeState();

  bool get isSubmitting => this is CodeSubmitting;

  bool get canSubmit => this is CodeInitial || this is CodeFailure;
}

final class const CodeInitial() extends CodeState {}

final class const CodeSuccess() extends CodeState {}

final class const CodeSubmitting() extends CodeState {}

final class const CodeFailure({required final ErrorsEntity errors})
    extends CodeState {}
