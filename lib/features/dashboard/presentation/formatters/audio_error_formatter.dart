import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';

abstract final class AudioErrorFormatter {
  static String title(AudioFailureEnum failure) => switch (failure) {
    .empty => 'Gravação vazia',
    .unexpected => 'Falha na captura',
    .permission => 'Permissão necessária',
    .unavailable => 'Recurso indisponível',
    .interrupted => 'Captura interrompida',
    .sendingUnavailable => 'Envio indisponível',
  };

  static String description(AudioFailureEnum failure) => switch (failure) {
    .permission => 'Permita o microfone nos ajustes.',
    .empty => 'Nenhum áudio foi gravado nesta captura.',
    .unexpected => 'Não foi possível concluir a gravação.',
    .interrupted => 'A gravação foi encerrada antes da conclusão.',
    .sendingUnavailable => 'O envio de áudio ainda não está disponível.',
    .unavailable => 'A gravação de áudio não está disponível neste aparelho.',
  };
}
