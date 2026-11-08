import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';

abstract final class ExpenseErrorMessageFormatter {
  static String reregistration(ErrorsEntity errors) {
    const fallback = 'Tente novamente em instantes.';
    final messages = errors.errors
        .map((error) => format(error, fallback: fallback))
        .toSet();

    return messages.isEmpty ? fallback : messages.join('\n');
  }

  static ({String? cents, String? description, String? date, String? toast})
  fields(ErrorsEntity errors, {required bool isEditing}) {
    final dateMessages = <String>[];
    final amountMessages = <String>[];
    final remaining = <ErrorEntity>[];
    final descriptionMessages = <String>[];

    for (final error in errors.errors) {
      if (error.status != '422' && error.status != '400') {
        remaining.add(error);
        continue;
      }

      final message = format(error, fallback: 'Confira os dados informados.');

      switch (error.pointer) {
        case '/data/attributes/amount':
        case '/amount':
          amountMessages.add(message);
        case '/data/attributes/description':
        case '/description':
          descriptionMessages.add(message);
        case '/data/attributes/occurred_on':
        case '/occurred_on':
          dateMessages.add(message);
        default:
          remaining.add(error);
      }
    }

    final fallback = isEditing
        ? 'Não foi possível atualizar o gasto. Tente novamente.'
        : 'Não foi possível cadastrar o gasto. Tente novamente.';
    final toastMessages = remaining
        .map((error) => format(error, fallback: fallback))
        .toSet();
    String? toast;

    if (remaining.isNotEmpty || errors.errors.isEmpty) {
      toast = toastMessages.isEmpty ? fallback : toastMessages.join('\n');
    }

    return (
      cents: amountMessages.isEmpty ? null : amountMessages.join('\n'),
      description: descriptionMessages.isEmpty
          ? null
          : descriptionMessages.join('\n'),
      date: dateMessages.isEmpty ? null : dateMessages.join('\n'),
      toast: toast,
    );
  }

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
