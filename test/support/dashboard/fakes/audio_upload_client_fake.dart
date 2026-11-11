import 'dart:async';

import 'package:http/http.dart' as http;

final class AudioUploadClientFake extends http.BaseClient {
  bool closed = false;
  final started = Completer<void>();
  final requests = <http.BaseRequest>[];
  final response = Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    if (!started.isCompleted) {
      started.complete();
    }
    return response.future;
  }

  @override
  void close() {
    closed = true;
  }
}
