import 'package:cordato/features/core/domain/entities/errors_entity.dart';

abstract final class ErrorMessageFormatter {
  static String format(ErrorEntity error, {required String fallback}) =>
      fallback;

  static String formatAll(
    Iterable<ErrorEntity> errors, {
    required String fallback,
  }) {
    final messages = errors
        .map((error) => format(error, fallback: fallback))
        .toSet();
    return messages.isEmpty ? fallback : messages.join('\n');
  }
}
