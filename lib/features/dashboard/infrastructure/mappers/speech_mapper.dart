import 'package:cordato/features/core/application/events/recognition_event.dart';
import 'package:cordato/features/core/application/enums/recognition_failure_enum.dart';
import 'package:cordato/features/core/application/exceptions/recognition_exception.dart';

import 'package:cordato/features/dashboard/application/enums/speech_failure_enum.dart';
import 'package:cordato/features/dashboard/application/events/speech_update_event.dart';
import 'package:cordato/features/dashboard/application/exceptions/speech_exception.dart';

abstract final class SpeechMapper {
  static SpeechUpdateEvent? update(RecognitionEvent event) => switch (event) {
    RecognitionText() => null,
    RecognitionEnded() => const SpeechReadyUpdateEvent(),
    RecognitionListening() => const SpeechListeningUpdateEvent(),
    RecognitionLevel(:final level) => SpeechLevelUpdateEvent(level),
  };

  static Object exception(Object error) => switch (error) {
    RecognitionException(:final failure) => SpeechException(_failure(failure)),
    _ => error,
  };

  static SpeechFailureEnum _failure(RecognitionFailureEnum failure) =>
      switch (failure) {
        .timeout => .timeout,
        .language => .language,
        .permission => .permission,
        .unavailable => .unavailable,
        .interrupted => .interrupted,
      };
}
