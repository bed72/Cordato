sealed class const Failure(final String message) {
  @override
  String toString() => message;
}

final class const UnknownFailure([
  super.message = 'Ocorreu um erro inesperado.',
]) extends Failure;

final class const LogoutFailure([
  super.message = 'Não foi possível encerrar a sessão.',
]) extends Failure;

final class const MagicLinkRequestFailure([
  super.message = 'Não foi possível enviar o link de acesso.',
]) extends Failure;

final class const MagicLinkConfirmationFailure([
  super.message = 'Não foi possível confirmar o código de acesso.',
]) extends Failure;
