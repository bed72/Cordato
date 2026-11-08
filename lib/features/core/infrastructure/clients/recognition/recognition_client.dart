import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:cordato/features/core/application/events/recognition_event.dart';
import 'package:cordato/features/core/application/enums/recognition_failure_enum.dart';
import 'package:cordato/features/core/application/exceptions/recognition_exception.dart';
import 'package:cordato/features/core/application/clients/interface_recognition_client.dart';
import 'package:cordato/features/core/infrastructure/clients/recognition/mappers/recognition_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/recognition/models/recognition_session_model.dart';

final class RecognitionClient implements IRecognitionClient {
  final SpeechToText _recognizer = SpeechToText();

  Future<void>? _pendingPreparation;
  Future<bool>? _pendingInitialization;
  Future<void> _pendingRelease = Future<void>.value();

  RecognitionSessionModel? _activeSession;
  RecognitionSessionModel? _nativeCallbackSession;

  @override
  Stream<RecognitionEvent> start({required int operation}) {
    late final RecognitionSessionModel session;

    final events = StreamController<RecognitionEvent>(
      onListen: () => _activateSession(session),
      onCancel: () => discard(operation: operation),
    );

    session = RecognitionSessionModel(operation: operation, events: events);

    return events.stream;
  }

  @override
  Future<String> finish({required int operation}) async {
    final session = _requireActiveSession(operation);

    if (!session.finalTranscript.isCompleted && !session.isFinalizing) {
      session.isFinalizing = true;
      _scheduleFinalizationTimeout(session);
      unawaited(_stopRecognition(session));
    }

    final transcript = await session.finalTranscript.future;

    if (!_isActiveSession(session) || session.failure != null) {
      throw RecognitionException(
        session.failure ?? RecognitionFailureEnum.interrupted,
      );
    }

    return transcript;
  }

  @override
  Future<void> discard({required int operation}) async {
    final session = _activeSession;

    if (session == null || session.operation != operation) {
      return;
    }

    _activeSession = null;

    if (identical(_nativeCallbackSession, session)) {
      _nativeCallbackSession = null;
    }

    session.completeTranscript('');
    _pendingRelease = _releaseRecognition();
    unawaited(session.events.close());

    await _pendingRelease;
  }

  bool _isActiveSession(RecognitionSessionModel session) =>
      identical(_activeSession, session);

  RecognitionSessionModel _requireActiveSession(int operation) {
    final session = _activeSession;

    if (session == null || session.operation != operation) {
      throw const RecognitionException(RecognitionFailureEnum.interrupted);
    }

    return session;
  }

  void _activateSession(RecognitionSessionModel session) {
    final previousSession = _activeSession;

    if (previousSession != null) {
      unawaited(discard(operation: previousSession.operation));
    }

    _activeSession = session;
    _pendingPreparation = _prepareAfterPreviousSession(
      session,
      _pendingPreparation,
    );
  }

  Future<void> _prepareAfterPreviousSession(
    RecognitionSessionModel session,
    Future<void>? previousPreparation,
  ) async {
    await previousPreparation;
    await _prepareRecognition(session);
  }

  Future<void> _prepareRecognition(RecognitionSessionModel session) async {
    try {
      await _pendingRelease;

      if (!_isActiveSession(session)) {
        return;
      }

      await _initializeRecognizer(session);

      if (!_isActiveSession(session)) {
        return;
      }

      final localeId = await _selectBrazilianPortuguese();
      if (!_isActiveSession(session)) {
        return;
      }

      await _listen(session, localeId: localeId);
    } on RecognitionException catch (exception) {
      _failSession(session, exception.failure);
    } on PlatformException {
      _failSession(session, RecognitionFailureEnum.unavailable);
    } on MissingPluginException {
      _failSession(session, RecognitionFailureEnum.unavailable);
    } on ListenFailedException {
      _failSession(session, RecognitionFailureEnum.unavailable);
    } catch (error, stackTrace) {
      _reportUnexpectedFailure(session, error, stackTrace);
    }
  }

  Future<void> _initializeRecognizer(RecognitionSessionModel session) async {
    _nativeCallbackSession = session;

    final available = await (_pendingInitialization ??= _recognizer.initialize(
      finalTimeout: .zero,
      onStatus: _handleStatus,
      onError: _handleNativeError,
      options: [SpeechToText.androidNoBluetooth],
    ));

    if (available || !_isActiveSession(session)) {
      return;
    }

    _pendingInitialization = null;

    final permitted = await _recognizer.hasPermission;
    final failure = permitted
        ? RecognitionFailureEnum.unavailable
        : RecognitionFailureEnum.permission;

    throw RecognitionException(failure);
  }

  Future<String> _selectBrazilianPortuguese() async {
    final supportedLocales = await _recognizer.locales();

    for (final locale in supportedLocales) {
      final languageTag = locale.localeId.replaceAll('_', '-').toLowerCase();

      if (languageTag == 'pt-br') {
        return locale.localeId;
      }
    }

    throw const RecognitionException(.language);
  }

  Future<void> _listen(
    RecognitionSessionModel session, {
    required String localeId,
  }) async {
    _scheduleFinalizationTimeout(session);

    await _recognizer.listen(
      listenOptions: SpeechListenOptions(
        onDevice: false,
        localeId: localeId,
        cancelOnError: false,
        partialResults: true,
        listenMode: .confirmation,
        listenFor: const Duration(seconds: 30),
      ),
      onResult: (recognition) => _handleTranscript(session, recognition),
      onSoundLevelChange: (decibels) => _handleSoundLevel(session, decibels),
    );

    if (!_isActiveSession(session)) {
      await _recognizer.cancel();
    }
  }

  void _handleTranscript(
    RecognitionSessionModel session,
    SpeechRecognitionResult recognition,
  ) {
    if (!_isActiveSession(session) || session.finalTranscript.isCompleted) {
      return;
    }

    session.events.add(
      RecognitionText(
        isFinal: recognition.finalResult,
        text: recognition.recognizedWords,
      ),
    );

    if (recognition.finalResult) {
      _completeSession(session, recognition.recognizedWords);
    }
  }

  void _handleSoundLevel(RecognitionSessionModel session, double decibels) {
    if (!_isActiveSession(session) ||
        session.finalTranscript.isCompleted ||
        session.isFinalizing) {
      return;
    }

    final level = RecognitionMapper.soundLevel(
      decibels: decibels,
      platform: defaultTargetPlatform,
    );

    session.events.add(RecognitionLevel(level));
  }

  void _handleNativeError(SpeechRecognitionError nativeError) {
    final session = _nativeCallbackSession;

    if (session == null || !_isActiveSession(session)) {
      return;
    }

    switch (RecognitionMapper.failure(nativeError.errorMsg)) {
      case null:
        _completeSession(session, '');
      case final failure:
        _failSession(session, failure);
    }
  }

  void _handleStatus(String status) {
    final session = _nativeCallbackSession;

    if (session == null ||
        !_isActiveSession(session) ||
        session.finalTranscript.isCompleted) {
      return;
    }

    switch (status) {
      case SpeechToText.listeningStatus:
        session.cancelTimeout();
        session.events.add(const RecognitionListening());
      case SpeechToText.notListeningStatus:
        session.isFinalizing = true;
        _scheduleFinalizationTimeout(session);
      case SpeechToText.doneStatus:
        _completeSession(session, '');
    }
  }

  void _scheduleFinalizationTimeout(RecognitionSessionModel session) {
    session.finalizationTimeout ??= Timer(
      const Duration(seconds: 5),
      () => _failSession(session, .timeout),
    );
  }

  void _completeSession(RecognitionSessionModel session, String transcript) {
    if (!_isActiveSession(session) || session.finalTranscript.isCompleted) {
      return;
    }

    session.completeTranscript(transcript);
    session.events.add(const RecognitionEnded());
    _pendingRelease = _releaseRecognition();
  }

  void _failSession(
    RecognitionSessionModel session,
    RecognitionFailureEnum failure,
  ) {
    if (!_isActiveSession(session)) {
      return;
    }

    session.failure = failure;
    session.completeTranscript('');
    session.events.addError(RecognitionException(failure));
    unawaited(discard(operation: session.operation));
  }

  void _reportUnexpectedFailure(
    RecognitionSessionModel session,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!_isActiveSession(session)) {
      return;
    }

    session.failure = .interrupted;
    session.completeTranscript('');
    session.events.addError(error, stackTrace);
    unawaited(discard(operation: session.operation));
  }

  Future<void> _stopRecognition(RecognitionSessionModel session) async {
    try {
      await _recognizer.stop();
    } on PlatformException {
      _failSession(session, RecognitionFailureEnum.interrupted);
    } on MissingPluginException {
      _failSession(session, RecognitionFailureEnum.unavailable);
    } catch (error, stackTrace) {
      _reportUnexpectedFailure(session, error, stackTrace);
    }
  }

  Future<void> _releaseRecognition() async {
    try {
      await _recognizer.cancel();
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
