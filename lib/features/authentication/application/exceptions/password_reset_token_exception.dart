import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class PasswordResetTokenException({required final ErrorsEntity errors})
    implements Exception {}
