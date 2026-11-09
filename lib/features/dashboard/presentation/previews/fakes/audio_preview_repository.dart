import 'dart:async';

import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_audio_repository.dart';

final class AudioPreviewRepository implements IAudioRepository {
  StreamController<RecordingEvent>? _updates;

  @override
  Stream<RecordingEvent> start({required int operation}) {
    final controller = StreamController<RecordingEvent>();
    _updates = controller;
    controller.onListen = () {
      controller.add(const RecordingListening());

      for (int index = 0; index < 32; index++) {
        controller.add(RecordingLevel((index % 7 + 1) / 8));
      }

      controller.add(const RecordingEnded());
    };

    controller.onCancel = () {
      if (identical(_updates, controller)) {
        _updates = null;
      }
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
}
