import 'package:cordato/features/core/domain/entities/errors_entity.dart';

abstract final class ErrorMessageFormatter {
  static String format(ErrorEntity error, {required String fallback}) =>
      switch (error.status) {
        '401' => 'Sua sessão expirou. Entre novamente.',
        '403' => 'Você não tem permissão para realizar esta ação.',
        '404' => 'Não foi possível encontrar os dados solicitados.',
        '408' ||
        '504' => 'A resposta demorou mais que o esperado. Tente novamente.',
        '429' => 'Muitas tentativas. Aguarde um pouco e tente novamente.',
        final status when _isServerError(status) =>
          'O serviço está indisponível no momento. Tente novamente mais tarde.',
        _ => fallback,
      };

  static String formatAll(
    Iterable<ErrorEntity> errors, {
    required String fallback,
  }) {
    final messages = errors
        .map((error) => format(error, fallback: fallback))
        .toSet();
    return messages.isEmpty ? fallback : messages.join('\n');
  }

  static bool _isServerError(String? status) {
    final value = int.tryParse(status ?? '');
    return value != null && value >= 500 && value <= 599;
  }
}
