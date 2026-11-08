import 'dart:async';

import 'package:cordato/features/core/application/events/recognition_event.dart';
import 'package:cordato/features/core/application/enums/recognition_failure_enum.dart';

final class RecognitionSessionModel({
  required final int operation,
  required final StreamController<RecognitionEvent> events,
}) {
  final finalTranscript = Completer<String>();
  bool isFinalizing = false;
  Timer? finalizationTimeout;
  RecognitionFailureEnum? failure;

  void cancelTimeout() {
    finalizationTimeout?.cancel();
    finalizationTimeout = null;
  }

  void completeTranscript(String transcript) {
    cancelTimeout();

    if (!finalTranscript.isCompleted) finalTranscript.complete(transcript);
  }
}
