final class const ErrorsEntity({required final List<ErrorEntity> errors}) {
  factory ErrorsEntity.unknown() => const ErrorsEntity(
    errors: [
      ErrorEntity(
        title: 'Erro desconhecido',
        detail: 'Não foi possível processar a resposta.',
      ),
    ],
  );
}

final class const ErrorEntity({
  final String? title,
  final String? detail,
  final String? status,
  final String? pointer,
  final String? parameter,
});
