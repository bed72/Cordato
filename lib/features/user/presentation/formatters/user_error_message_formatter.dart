import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';

abstract final class UserErrorMessageFormatter {
  static String format(ErrorEntity error, {required String fallback}) {
    if ((error.status == '400' || error.status == '422') &&
        (error.pointer == '/name' ||
            error.pointer == '/data/attributes/name')) {
      return switch (error.code) {
        'validation_required' => 'Informe seu nome.',
        'validation_length_out_of_range' ||
        'validation_length' => 'O nome deve ter entre 2 e 32 caracteres.',
        _ => 'Confira o nome informado.',
      };
    }

    return ErrorMessageFormatter.format(error, fallback: fallback);
  }
}
