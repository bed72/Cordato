import 'dart:async';

import 'package:cordato/features/dashboard/application/events/speech_update_event.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_speech_repository.dart';

final class SpeechPreviewRepository implements ISpeechRepository {
  StreamController<SpeechUpdateEvent>? _updates;

  @override
  Stream<SpeechUpdateEvent> start({required int operation}) {
    final controller = StreamController<SpeechUpdateEvent>();
    _updates = controller;
    controller.onListen = () {
      controller.add(const SpeechListeningUpdateEvent());

      for (int index = 0; index < 32; index++) {
        controller.add(SpeechLevelUpdateEvent((index % 7 + 1) / 8));
      }

      controller.add(const SpeechReadyUpdateEvent());
    };

    controller.onCancel = () {
      if (identical(_updates, controller)) _updates = null;
    };

    return controller.stream;
  }

  @override
  Future<void> finish({required int operation}) async {}

  @override
  Future<void> discard({required int operation}) async {
    final controller = _updates;
    _updates = null;
    unawaited(controller?.close());
  }

  @override
  void confirmDiagnostic({required int operation}) {}
}
