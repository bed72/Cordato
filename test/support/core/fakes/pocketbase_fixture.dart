import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class PocketBaseFixture {
  static const token =
      'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.signature';

  final List<http.Request> requests = [];
  FutureOr<http.Response> Function(http.Request) respond = (_) =>
      http.Response('', 204);

  late final PocketBase client = PocketBase(
    'https://example.com',
    lang: 'pt-BR',
    httpClientFactory: () => MockClient((request) async {
      requests.add(request);
      return await respond(request);
    }),
  )..autoClearAuthStore(false);

  static http.Response jsonResponse(
    Map<String, dynamic> body, {
    int status = 200,
  }) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  static http.Response authResponse({
    String authToken = token,
    String id = 'user-1',
  }) => jsonResponse({
    'token': authToken,
    'record': {'id': id, 'collectionName': 'users', 'collectionId': 'users-id'},
  });

  void authenticate({String authToken = token, String id = 'user-1'}) {
    client.authStore.save(
      authToken,
      RecordModel.fromJson({
        'id': id,
        'collectionName': 'users',
        'collectionId': 'users-id',
      }),
    );
  }
}
