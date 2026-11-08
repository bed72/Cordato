import 'package:cordato/features/dashboard/application/enums/speech_failure_enum.dart';

abstract final class SpeechErrorFormatter {
  static String title(SpeechFailureEnum failure) => switch (failure) {
    .language => 'Idioma indisponível',
    .unexpected => 'Falha na captura',
    .timeout => 'Captura não concluída',
    .empty => 'Nenhuma fala reconhecida',
    .permission => 'Permissão necessária',
    .unavailable => 'Recurso indisponível',
    .interrupted => 'Captura interrompida',
  };

  static String description(SpeechFailureEnum failure) => switch (failure) {
    .empty => 'Não identificamos fala nesta captura.',
    .unexpected => 'Não foi possível reconhecer a fala.',
    .timeout => 'Não foi possível finalizar a fala a tempo.',
    .interrupted => 'O reconhecimento foi encerrado antes da conclusão.',
    .permission =>
      'Permita o microfone e o reconhecimento de fala nos ajustes.',
    .unavailable =>
      'O reconhecimento de fala não está disponível neste aparelho.',
    .language => 'Português brasileiro não está disponível no reconhecedor.',
  };
}
