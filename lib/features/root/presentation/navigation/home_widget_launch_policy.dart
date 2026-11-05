import 'package:cordato/features/session/presentation/bloc/session_state.dart';

enum HomeWidgetLaunchAction { wait, signIn, openExpense }

abstract final class HomeWidgetLaunchPolicy {
  static HomeWidgetLaunchAction action({
    required bool pending,
    required bool deferred,
    required SessionState state,
  }) {
    if (!pending || deferred) {
      return .wait;
    }

    return switch (state) {
      SessionUnauthenticated() => .signIn,
      SessionAuthenticated() => .openExpense,
      SessionInitial() || SessionLoading() || SessionFailure() => .wait,
    };
  }
}
