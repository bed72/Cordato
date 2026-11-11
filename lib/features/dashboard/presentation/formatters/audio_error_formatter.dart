import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';

abstract final class AudioErrorFormatter {
  static String title(AudioFailureEnum failure) => switch (failure) {
    .empty => 'Gravação vazia',
    .rejected => 'Áudio recusado',
    .unexpected => 'Falha no áudio',
    .busy => 'Processamento ocupado',
    .tooLarge => 'Áudio muito grande',
    .unauthorized => 'Sessão inválida',
    .forbidden => 'Envio não autorizado',
    .permission => 'Permissão necessária',
    .unavailable => 'Recurso indisponível',
    .interrupted => 'Captura interrompida',
    .sendingUnavailable => 'Envio indisponível',
    .unsupportedFormat => 'Formato incompatível',
    .submissionUnknown => 'Envio sem confirmação',
  };

  static String description(AudioFailureEnum failure) => switch (failure) {
    .permission => 'Permita o microfone nos ajustes.',
    .empty => 'Nenhum áudio foi gravado nesta captura.',
    .unexpected => 'Não foi possível concluir a operação de áudio.',
    .interrupted => 'A gravação foi encerrada antes da conclusão.',
    .sendingUnavailable => 'O envio de áudio está indisponível no momento.',
    .unavailable => 'A gravação de áudio não está disponível neste aparelho.',
    .unauthorized => 'Entre novamente para enviar o áudio.',
    .forbidden => 'Sua conta não tem autorização para enviar este áudio.',
    .tooLarge => 'O áudio deve ter até 2 MiB.',
    .unsupportedFormat => 'Envie uma gravação M4A com tipo audio/mp4.',
    .busy => 'Tente novamente mais tarde.',
    .rejected => 'Não foi possível aceitar esta gravação.',
    .submissionUnknown => 'O áudio pode estar em processamento. Confira suas despesas antes de reenviar.',
  };
}
