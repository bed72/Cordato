import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

abstract final class SessionRoutePolicy {
  static String? redirect({
    required SessionState state,
    required String path,
    required bool deferred,
    bool afterDeferral = false,
  }) {
    if (deferred) return null;
    if (afterDeferral && state is SessionAuthenticated) return null;
    final protected = RouteEnum.authenticatedPaths().contains(path);
    final splash = path == RouteEnum.app.path;
    return switch (state) {
      SessionInitial() ||
      SessionLoading() => protected ? RouteEnum.app.path : null,
      SessionAuthenticated() =>
        splash ||
                path == RouteEnum.welcome.path ||
                path == RouteEnum.authenticationSignIn.path
            ? RouteEnum.dashboard.path
            : null,
      SessionUnauthenticated() ||
      SessionFailure() => splash || protected ? RouteEnum.welcome.path : null,
    };
  }
}
