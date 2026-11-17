import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

abstract final class SessionRoutePolicy {
  static String? redirect({required SessionState state, required String path}) {
    final splash = path == RouteEnum.app.path;
    final protected = RouteEnum.authenticatedPaths().contains(path);

    return switch (state) {
      SessionInitial() ||
      SessionLoading() => protected ? RouteEnum.app.path : null,
      SessionAuthenticated() =>
        splash ||
                path == RouteEnum.welcome.path ||
                path == RouteEnum.authenticationSignIn.path ||
                path == RouteEnum.authenticationConfirm.path
            ? RouteEnum.dashboard.path
            : null,
      SessionUnauthenticated() ||
      SessionFailure() => splash || protected ? RouteEnum.welcome.path : null,
    };
  }
}
