import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/core/application/exceptions/recording_exception.dart';
import 'package:cordato/features/core/application/clients/interface_recording_client.dart';

import 'package:cordato/features/dashboard/application/exceptions/audio_exception.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_audio_repository.dart';

final class AudioRepository({required final IRecordingClient client})
    implements IAudioRepository {
  @override
  Stream<RecordingEvent> start({required int operation}) => client
      .start(operation: operation)
      .handleError((Object error, StackTrace stackTrace) {
        Error.throwWithStackTrace(_captureFailure(error), stackTrace);
      });

  @override
  Future<void> finish({required int operation}) async {
    try {
      final audio = await client.finish(operation: operation);
      if (audio.isEmpty) {
        throw const AudioException(.empty);
      }

      throw const AudioException(.sendingUnavailable);
    } on RecordingException catch (exception) {
      throw _captureFailure(exception);
    } finally {
      await discard(operation: operation);
    }
  }

  @override
  Future<void> discard({required int operation}) =>
      client.discard(operation: operation);

  Object _captureFailure(Object error) => switch (error) {
    RecordingException(:final failure) => AudioException(switch (failure) {
      .empty => .empty,
      .permission => .permission,
      .unavailable => .unavailable,
      .interrupted => .interrupted,
    }),
    _ => error,
  };
}
