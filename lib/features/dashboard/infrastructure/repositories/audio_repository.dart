import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/core/application/exceptions/recording_exception.dart';
import 'package:cordato/features/core/application/clients/interface_recording_client.dart';

import 'package:cordato/features/dashboard/application/exceptions/audio_exception.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_audio_repository.dart';

final class AudioRepository({
  required final PocketBase pocketBase,
  required final IRecordingClient client,
  String workerUrl = const String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'https://worker.cordato.cloud',
  ),
}) implements IAudioRepository {
  final Uri _endpoint = _workerEndpoint(workerUrl);

  @override
  Stream<RecordingEvent> start({required int operation}) => client
      .start(operation: operation)
      .handleError((Object error, StackTrace stackTrace) {
        Error.throwWithStackTrace(_captureFailure(error), stackTrace);
      });

  @override
  Future<void> finish({required int operation}) async {
    final Uint8List audio;
    try {
      audio = await client.finish(operation: operation);
      if (audio.isEmpty) {
        throw const AudioException(.empty);
      }

      if (audio.length > 2 * 1024 * 1024) {
        throw const AudioException(.tooLarge);
      }
    } on RecordingException catch (exception) {
      throw _captureFailure(exception);
    } finally {
      await discard(operation: operation);
    }

    await _send(audio);
  }

  @override
  Future<void> discard({required int operation}) =>
      client.discard(operation: operation);

  Future<void> _send(Uint8List audio) async {
    final token = pocketBase.authStore.token;
    if (token.isEmpty) throw const AudioException(.unauthorized);

    final today = DateTime.now();
    final referenceDate =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final request = http.MultipartRequest('POST', _endpoint)
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['reference_date'] = referenceDate
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          audio,
          filename: 'audio.m4a',
          contentType: MediaType('audio', 'mp4'),
        ),
      );
    final transport = http.Client();

    try {
      final response = await transport
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));

      _confirmAcceptance(response);
    } on TimeoutException {
      throw const AudioException(.submissionUnknown);
    } on http.ClientException {
      throw const AudioException(.submissionUnknown);
    } finally {
      transport.close();
    }
  }

  void _confirmAcceptance(http.Response response) {
    if (response.statusCode != 202) {
      throw AudioException(switch (response.statusCode) {
        429 => .busy,
        413 => .tooLarge,
        400 => .rejected,
        403 => .forbidden,
        401 => .unauthorized,
        415 => .unsupportedFormat,
        411 || 503 => .sendingUnavailable,
        _ => .submissionUnknown,
      });
    }

    final Object? acceptance;
    try {
      acceptance = jsonDecode(response.body);
    } on FormatException {
      throw const AudioException(.submissionUnknown);
    }

    if (acceptance is! Map<String, dynamic> ||
        acceptance['status'] != 'processing' ||
        acceptance['request_id'] is! String ||
        (acceptance['request_id'] as String).trim().isEmpty) {
      throw const AudioException(.submissionUnknown);
    }
  }

  static Uri _workerEndpoint(String address) {
    final uri = Uri.parse(address);
    if (uri.scheme != 'https' ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('WORKER_URL deve ser uma origem HTTPS.');
    }

    return uri.resolve('/api/collections/audio/process');
  }

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
