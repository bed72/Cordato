import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/enums/app_route.dart';

void main() {
  test('exposes the application route paths', () {
    expect(AppRoute.root.path, '/');
    expect(AppRoute.welcome.path, '/welcome');
    expect(AppRoute.dashboard.path, '/dashboard');
    expect(AppRoute.authenticationMagicLink.path, '/authentication/magic-link');
    expect(AppRoute.authenticationCallback.path, '/callback');
  });
}
