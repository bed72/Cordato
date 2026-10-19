import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class AuthenticationException({required final ErrorsEntity errors})
    implements Exception {}
