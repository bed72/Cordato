import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

void main() {
  test('exposes the application route paths', () {
    expect(RouteEnum.root.path, '/');
    expect(RouteEnum.welcome.path, '/welcome');
    expect(RouteEnum.splash.path, '/splash');
    expect(RouteEnum.dashboard.path, '/dashboard');
    expect(RouteEnum.authenticationSignIn.path, '/authentication/sign-in');
  });
}
