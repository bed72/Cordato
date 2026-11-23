import 'package:cordato/features/core/domain/entities/errors_entity.dart';

abstract final class ExpenseErrorMessageFormatter {
  static String reregistration(ErrorsEntity errors) {
    const fallback = 'Tente novamente em instantes.';
    final messages = errors.errors
        .map((error) => format(error, fallback: fallback))
        .toSet();

    return messages.isEmpty ? fallback : messages.join('\n');
  }

  static ({String? cents, String? toast}) fields(
    ErrorsEntity errors, {
    required bool isEditing,
  }) {
    final amountMessages = <String>{};
    final remaining = <ErrorEntity>[];

    for (final error in errors.errors) {
      if (error.code == 'invalid_amount' && error.parameter == 'amount') {
        amountMessages.add(
          format(error, fallback: 'Confira o valor informado.'),
        );
      } else {
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
      toast: toast,
    );
  }

  static String format(ErrorEntity error, {required String fallback}) =>
      switch (error.code) {
        'invalid_amount' => 'Informe um valor maior que zero.',
        'expense_not_found' => 'Não foi possível encontrar a despesa.',
        'profile_not_found' =>
          'Não foi possível carregar seu perfil. Tente novamente.',
        _ => fallback,
      };
}
