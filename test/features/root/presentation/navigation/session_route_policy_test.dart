import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/navigation/session_redirect_deferral.dart';
import 'package:cordato/features/root/presentation/navigation/session_route_policy.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

void main() {
  group('Protected password route', () {
    for (final state in [const SessionInitial(), const SessionLoading()]) {
      test('${state.runtimeType} sends direct entry to session validation', () {
        expect(
          SessionRoutePolicy.redirect(
            state: state,
            path: RouteEnum.authenticationChangePassword.path,
            deferred: false,
          ),
          RouteEnum.app.path,
        );
      });
    }
    test('unauthenticated direct entry redirects normally', () {
      expect(
        SessionRoutePolicy.redirect(
          state: const SessionUnauthenticated(),
          path: RouteEnum.authenticationChangePassword.path,
          deferred: false,
        ),
        RouteEnum.welcome.path,
      );
    });
  });

  group('Logout completion', () {
    test(
      'releasing after clear does not reuse a stale authenticated observation',
      () {
        expect(
          SessionRoutePolicy.redirect(
            state: const SessionAuthenticated(),
            path: RouteEnum.authenticationSignIn.path,
            deferred: false,
            afterDeferral: true,
          ),
          isNull,
        );
        expect(
          SessionRoutePolicy.redirect(
            state: const SessionUnauthenticated(),
            path: RouteEnum.authenticationSignIn.path,
            deferred: false,
          ),
          isNull,
        );
      },
    );
    test('keeps the route during token removal and preserves sign-in after release', () {
      var path = RouteEnum.authenticationChangePassword.path;
      String? redirect;
      late SessionRedirectDeferral deferral;
      void reevaluate() {
        redirect = SessionRoutePolicy.redirect(
          state: const SessionUnauthenticated(),
          path: path,
          deferred: deferral.isDeferredFor(path),
        );
      }

      deferral = SessionRedirectDeferral(onReleased: reevaluate);
      final release = deferral.hold(path);
      reevaluate();
      expect(redirect, isNull);
      path = RouteEnum.authenticationSignIn.path;
      release();
      expect(redirect, isNull);
    });

    test('disposal releases normal protection if the flow does not finish', () {
      final path = RouteEnum.authenticationChangePassword.path;
      String? redirect;
      late SessionRedirectDeferral deferral;
      deferral = SessionRedirectDeferral(
        onReleased: () {
          redirect = SessionRoutePolicy.redirect(
            state: const SessionUnauthenticated(),
            path: path,
            deferred: deferral.isDeferredFor(path),
          );
        },
      );
      final release = deferral.hold(path);
      release();
      expect(redirect, RouteEnum.welcome.path);
    });

    test('other logout destinations are unchanged', () {
      expect(
        SessionRoutePolicy.redirect(
          state: const SessionUnauthenticated(),
          path: RouteEnum.settings.path,
          deferred: false,
        ),
        RouteEnum.welcome.path,
      );
    });

    test('normal authenticated sign-in still redirects to dashboard', () {
      expect(
        SessionRoutePolicy.redirect(
          state: const SessionAuthenticated(),
          path: RouteEnum.authenticationSignIn.path,
          deferred: false,
        ),
        RouteEnum.dashboard.path,
      );
    });
  });
}
