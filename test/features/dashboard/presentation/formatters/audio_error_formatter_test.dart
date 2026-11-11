import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';
import 'package:cordato/features/dashboard/presentation/formatters/audio_error_formatter.dart';

void main() {
  for (final failure in AudioFailureEnum.values) {
    test(
      '${failure.name} has local feedback without transcription instructions',
      () {
        expect(AudioErrorFormatter.title(failure), isNotEmpty);
        expect(AudioErrorFormatter.description(failure), isNotEmpty);
        expect(
          AudioErrorFormatter.description(failure),
          isNot(contains('reconhecimento')),
        );
      },
    );
  }

  test('describes temporary sending unavailability', () {
    expect(
      AudioErrorFormatter.title(.sendingUnavailable),
      'Envio indisponível',
    );
    expect(
      AudioErrorFormatter.description(.sendingUnavailable),
      'O envio de áudio está indisponível no momento.',
    );
  });

  test('uncertain upload warns against duplicate submission', () {
    expect(
      AudioErrorFormatter.description(.submissionUnknown),
      contains('Confira suas despesas antes de reenviar'),
    );
  });
}
