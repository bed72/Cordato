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

  test('makes the unimplemented sending boundary explicit', () {
    expect(
      AudioErrorFormatter.title(.sendingUnavailable),
      'Envio indisponível',
    );
    expect(
      AudioErrorFormatter.description(.sendingUnavailable),
      'O envio de áudio ainda não está disponível.',
    );
  });
}
