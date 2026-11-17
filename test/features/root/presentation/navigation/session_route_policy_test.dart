import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/navigation/session_route_policy.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

void main() {
  group('Protected routes', () {
    for (final route in RouteEnum.values.where(
      (route) => route.authenticated,
    )) {
      for (final state in [const SessionInitial(), const SessionLoading()]) {
        test('${state.runtimeType} validates ${route.path} first', () {
          expect(
            SessionRoutePolicy.redirect(state: state, path: route.path),
            RouteEnum.app.path,
          );
        });
      }
      for (final state in [
        const SessionUnauthenticated(),
        const SessionFailure(),
      ]) {
        test('${state.runtimeType} leaves ${route.path}', () {
          expect(
            SessionRoutePolicy.redirect(state: state, path: route.path),
            RouteEnum.welcome.path,
          );
        });
      }
      test('authenticated ${route.path} stays open', () {
        expect(
          SessionRoutePolicy.redirect(
            state: const SessionAuthenticated(),
            path: route.path,
          ),
          isNull,
        );
      });
    }
  });

  group('Authentication completion', () {
    for (final route in [
      RouteEnum.app,
      RouteEnum.welcome,
      RouteEnum.authenticationSignIn,
      RouteEnum.authenticationConfirm,
    ]) {
      test('authentication from ${route.path} redirects to dashboard', () {
        expect(
          SessionRoutePolicy.redirect(
            state: const SessionAuthenticated(),
            path: route.path,
          ),
          RouteEnum.dashboard.path,
        );
      });
    }
    for (final route in [
      RouteEnum.authenticationSignIn,
      RouteEnum.authenticationConfirm,
    ]) {
      for (final state in [
        const SessionInitial(),
        const SessionLoading(),
        const SessionUnauthenticated(),
        const SessionFailure(),
      ]) {
        test(
          '${state.runtimeType} preserves the public ${route.path} flow',
          () {
            expect(
              SessionRoutePolicy.redirect(state: state, path: route.path),
              isNull,
            );
          },
        );
      }
    }
    test('confirmed absence from splash opens welcome', () {
      expect(
        SessionRoutePolicy.redirect(
          state: const SessionUnauthenticated(),
          path: RouteEnum.app.path,
        ),
        RouteEnum.welcome.path,
      );
    });
  });
}
