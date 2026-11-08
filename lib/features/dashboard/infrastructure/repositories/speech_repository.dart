import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cordato/features/core/application/events/recognition_event.dart';
import 'package:cordato/features/core/application/exceptions/recognition_exception.dart';
import 'package:cordato/features/core/application/clients/interface_recognition_client.dart';

import 'package:cordato/features/dashboard/infrastructure/mappers/speech_mapper.dart';
import 'package:cordato/features/dashboard/application/events/speech_update_event.dart';
import 'package:cordato/features/dashboard/application/exceptions/speech_exception.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_speech_repository.dart';

final class SpeechRepository({
  required final IRecognitionClient client,
  final bool diagnosticEnabled = kDebugMode,
  final void Function(String) diagnosticOutput = debugPrintSynchronously,
}) implements ISpeechRepository {
  int? _activeOperation;
  String? _confirmedTranscript;

  @override
  Stream<SpeechUpdateEvent> start({required int operation}) {
    StreamSubscription<RecognitionEvent>? observation;
    late final StreamController<SpeechUpdateEvent> updates;

    updates = StreamController<SpeechUpdateEvent>(
      onListen: () {
        _activeOperation = operation;
        _confirmedTranscript = null;
        observation = _observeRecognition(
          updates: updates,
          operation: operation,
        );
      },
      onCancel: () async {
        await observation?.cancel();
        await discard(operation: operation);
      },
    );

    return updates.stream;
  }

  @override
  Future<void> finish({required int operation}) async {
    try {
      final transcript = await client.finish(operation: operation);

      if (_activeOperation != operation) return;

      if (transcript.trim().isEmpty) throw const SpeechException(.empty);

      _confirmedTranscript = transcript;
    } on RecognitionException catch (exception) {
      throw SpeechMapper.exception(exception);
    }
  }

  @override
  Future<void> discard({required int operation}) async {
    if (_activeOperation == operation) {
      _activeOperation = null;
      _confirmedTranscript = null;
    }

    await client.discard(operation: operation);
  }

  @override
  void confirmDiagnostic({required int operation}) {
    if (_activeOperation != operation) return;

    final transcript = _confirmedTranscript;
    _confirmedTranscript = null;

    if (!kDebugMode || !diagnosticEnabled || transcript == null) return;

    final singleLineTranscript = transcript.replaceAll(RegExp(r'[\r\n]+'), ' ');
    diagnosticOutput('[Speech capture POC] $singleLineTranscript');
  }

  StreamSubscription<RecognitionEvent> _observeRecognition({
    required int operation,
    required StreamController<SpeechUpdateEvent> updates,
  }) => client
      .start(operation: operation)
      .listen(
        (event) => _forwardUpdate(
          event: event,
          updates: updates,
          operation: operation,
        ),
        onDone: () => unawaited(updates.close()),
        onError: (Object error, StackTrace stackTrace) {
          updates.addError(SpeechMapper.exception(error), stackTrace);
        },
      );

  void _forwardUpdate({
    required int operation,
    required RecognitionEvent event,
    required StreamController<SpeechUpdateEvent> updates,
  }) {
    if (_activeOperation != operation) return;

    final update = SpeechMapper.update(event);

    if (update != null) updates.add(update);
  }
}
