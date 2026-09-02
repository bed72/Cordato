sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Ocorreu um erro inesperado.']);
}

final class LogoutFailure extends Failure {
  const LogoutFailure([super.message = 'Não foi possível encerrar a sessão.']);
}

final class MagicLinkRequestFailure extends Failure {
  const MagicLinkRequestFailure([
    super.message = 'Não foi possível enviar o link de acesso.',
  ]);
}

final class MagicLinkConfirmationFailure extends Failure {
  const MagicLinkConfirmationFailure([
    super.message = 'Não foi possível confirmar o link de acesso.',
  ]);
}
