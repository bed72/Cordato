import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/session/infrastructure/responses/session_response.dart';

void main() {
  test(
    'reads token and record id without requiring optional profile attributes',
    () {
      final response = SessionResponse.fromJson({
        'token': 'fixture-token',
        'record': {
          'id': 'fixture-user',
          'verified': true,
          'created': 'ignored',
        },
      });
      expect(response.token, 'fixture-token');
      expect(response.userId, 'fixture-user');
    },
  );

  for (final body in <Map<String, dynamic>>[
    {},
    {'token': 'token', 'record': []},
    {
      'token': null,
      'record': {'id': 'id'},
    },
    {
      'token': 'token',
      'record': {'id': 1},
    },
  ]) {
    test('rejects malformed required refresh attributes', () {
      expect(() => SessionResponse.fromJson(body), throwsA(isA<TypeError>()));
    });
  }
}
