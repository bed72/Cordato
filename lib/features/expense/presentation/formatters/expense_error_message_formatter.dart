import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';

abstract final class ExpenseErrorMessageFormatter {
  static String format(ErrorEntity error, {required String fallback}) {
    if (error.status == '400' || error.status == '422') {
      final field = error.pointer?.replaceFirst('/data/attributes', '');
      final required = error.code == 'validation_required';

      switch (field) {
        case '/amount':
          return required ||
                  error.code == 'validation_min_greater_equal_than_required'
              ? 'Informe um valor maior que zero.'
              : 'Confira o valor informado.';
        case '/description':
          if (required) return 'Informe uma descrição.';
          if (error.code == 'validation_length_out_of_range' ||
              error.code == 'validation_length') {
            return 'A descrição deve ter entre 2 e 128 caracteres.';
          }
          return 'Confira a descrição informada.';
        case '/occurred_on':
          return 'Informe uma data válida.';
        case '/category':
          return 'Selecione uma categoria válida.';
      }
    }

    return ErrorMessageFormatter.format(error, fallback: fallback);
  }
}
