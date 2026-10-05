import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';

void main() {
  test('encodes resource identifiers as a single path segment', () {
    final request = Requests.forPath(
      HttpPathEnum.user,
      pathParameters: {'id': 'a/b?c#d'},
    );
    expect(request.path, 'users/a%2Fb%3Fc%23d');
    expect(request.route, HttpPathEnum.user);
  });

  test('rejects missing, empty and traversal path parameters', () {
    for (final parameters in <Map<String, String>>[
      {},
      {'id': ''},
      {'id': '.'},
      {'id': '..'},
    ]) {
      expect(
        () => Requests.forPath(HttpPathEnum.user, pathParameters: parameters),
        throwsArgumentError,
      );
    }
  });
}
