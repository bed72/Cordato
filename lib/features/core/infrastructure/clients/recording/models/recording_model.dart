import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';

final class RecordingModel({
  required final int operation,
  required final AudioRecorder recorder,
  required final StreamController<RecordingEvent> events,
}) {
  Timer? limit;
  Directory? directory;
  Future<void>? preparation;
  Future<Uint8List>? finalization;
  StreamSubscription<RecordState>? states;
  StreamSubscription<Amplitude>? amplitudes;
  bool stopping = false;
}
