import 'dart:io';
import 'dart:async';

import 'package:record/record.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/core/application/exceptions/recording_exception.dart';
import 'package:cordato/features/core/application/clients/interface_recording_client.dart';
import 'package:cordato/features/core/infrastructure/clients/recording/models/recording_model.dart';

final class RecordingClient({
  final AudioRecorder Function() recorder = AudioRecorder.new,
  final Future<Directory> Function() directory = getTemporaryDirectory,
}) implements IRecordingClient {
  int? _releasingOperation;
  RecordingModel? _activeRecording;
  Future<void> _pendingRelease = Future<void>.value();

  @override
  Stream<RecordingEvent> start({required int operation}) {
    late final RecordingModel recording;
    final events = StreamController<RecordingEvent>(
      onListen: () => _activate(recording),
      onCancel: () => discard(operation: operation),
    );
    recording = RecordingModel(
      events: events,
      recorder: recorder(),
      operation: operation,
    );

    return events.stream;
  }

  @override
  Future<Uint8List> finish({required int operation}) async {
    final recording = _activeRecording;
    if (recording == null || recording.operation != operation) {
      throw const RecordingException(.interrupted);
    }

    await recording.preparation;
    _requireActive(recording);

    return recording.finalization ??= _stop(recording);
  }

  @override
  Future<void> discard({required int operation}) {
    final recording = _activeRecording;
    if (recording == null || recording.operation != operation) {
      return _releasingOperation == operation
          ? _pendingRelease
          : Future<void>.value();
    }

    _activeRecording = null;
    _releasingOperation = operation;

    recording.limit?.cancel();
    _pendingRelease = _release(recording);

    return _pendingRelease;
  }

  void _activate(RecordingModel recording) {
    final previous = _activeRecording;
    if (previous != null) unawaited(_discardRecording(previous));

    _activeRecording = recording;
    recording.preparation = _prepare(recording, _pendingRelease);
  }

  Future<void> _prepare(
    RecordingModel recording,
    Future<void> previousRelease,
  ) async {
    try {
      await previousRelease;
      if (!_isActive(recording)) return;

      await _requestPermission(recording);
      if (!_isActive(recording)) return;

      await _startRecorder(recording);
      if (!_isActive(recording)) return;

      _observeRecorder(recording);
      recording.events.add(const RecordingListening());
      recording.limit = Timer(const Duration(seconds: 30), () {
        unawaited(_finishAtLimit(recording));
      });
    } catch (error, stackTrace) {
      _fail(recording, error, stackTrace);
    }
  }

  Future<void> _requestPermission(RecordingModel recording) async {
    final permitted = await recording.recorder.hasPermission();
    if (!permitted) throw const RecordingException(.permission);
  }

  Future<void> _startRecorder(RecordingModel recording) async {
    final root = await directory();
    recording.directory = await root.createTemp('cordato_audio_');
    if (!_isActive(recording)) return;

    await recording.recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: '${recording.directory!.path}/capture.m4a',
    );
  }

  void _observeRecorder(RecordingModel recording) {
    void onError(Object error, StackTrace stackTrace) =>
        _fail(recording, error, stackTrace);

    recording.amplitudes = recording.recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(
          (amplitude) => _publishAmplitude(recording, amplitude.current),
          onError: onError,
        );
    recording.states = recording.recorder.onStateChanged().listen(
      (state) => _checkNativeState(recording, state),
      onError: onError,
    );
  }

  void _publishAmplitude(RecordingModel recording, double decibels) {
    if (!_isActive(recording) || recording.stopping) return;

    final level = decibels.isFinite
        ? ((decibels + 60) / 60).clamp(0.0, 1.0)
        : 0.0;
    recording.events.add(RecordingLevel(level));
  }

  void _checkNativeState(RecordingModel recording, RecordState state) {
    if (!_isActive(recording) ||
        recording.stopping ||
        state == RecordState.record) {
      return;
    }

    _fail(recording, const RecordingException(.interrupted), .current);
  }

  Future<Uint8List> _stop(RecordingModel recording) async {
    recording.stopping = true;
    recording.limit?.cancel();

    try {
      final path = await recording.recorder.stop();
      _requireActive(recording);
      if (path == null) throw const RecordingException(.empty);

      final audio = await File(path).readAsBytes();
      _requireActive(recording);
      if (audio.isEmpty) throw const RecordingException(.empty);

      return audio;
    } on PlatformException {
      throw const RecordingException(.interrupted);
    } on MissingPluginException {
      throw const RecordingException(.unavailable);
    }
  }

  Future<void> _finishAtLimit(RecordingModel recording) async {
    try {
      await finish(operation: recording.operation);
      if (_isActive(recording)) recording.events.add(const RecordingEnded());
    } catch (error, stackTrace) {
      _fail(recording, error, stackTrace);
    }
  }

  void _fail(RecordingModel recording, Object error, StackTrace stackTrace) {
    if (!_isActive(recording)) return;

    final failure = switch (error) {
      PlatformException() ||
      MissingPluginException() => const RecordingException(.unavailable),
      _ => error,
    };

    recording.events.addError(failure, stackTrace);
    unawaited(_discardRecording(recording));
  }

  Future<void> _discardRecording(RecordingModel recording) async {
    try {
      await discard(operation: recording.operation);
    } catch (error, stackTrace) {
      if (!recording.events.isClosed) {
        recording.events.addError(error, stackTrace);
      }
    }
  }

  bool _isActive(RecordingModel recording) =>
      identical(_activeRecording, recording);

  void _requireActive(RecordingModel recording) {
    if (!_isActive(recording)) throw const RecordingException(.interrupted);
  }

  Future<void> _release(RecordingModel recording) async {
    try {
      await recording.preparation;
      try {
        await recording.finalization;
      } catch (_) {
        if (!recording.stopping) rethrow;
      }

      await recording.amplitudes?.cancel();
      await recording.states?.cancel();
      await recording.recorder.cancel();
    } finally {
      try {
        await recording.recorder.dispose();
      } finally {
        final directory = recording.directory;
        if (directory != null && await directory.exists()) {
          await directory.delete(recursive: true);
        }
        unawaited(recording.events.close());
      }
    }
  }
}
