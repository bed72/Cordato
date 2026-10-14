import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class const CommandFailureException({required final ErrorsEntity errors})
    implements Exception {}
