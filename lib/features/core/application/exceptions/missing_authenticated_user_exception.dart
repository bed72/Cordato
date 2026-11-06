import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class const MissingAuthenticatedUserException() implements Exception {
  final ErrorsEntity errors = const ErrorsEntity(
    errors: [
      ErrorEntity(
        title: 'Usuário não identificado',
        detail: 'Não foi possível identificar o usuário.',
      ),
    ],
  );
}
