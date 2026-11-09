import 'dart:typed_data';

import 'package:cordato/features/core/application/events/recording_event.dart';

abstract interface class IRecordingClient {
  Future<void> discard({required int operation});
  Future<Uint8List> finish({required int operation});
  Stream<RecordingEvent> start({required int operation});
}
