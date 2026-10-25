import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class ExpenseException({required final ErrorsEntity errors})
    implements Exception {}
