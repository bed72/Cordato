import 'package:cordato/features/session/presentation/bloc/session_state.dart';

enum HomeWidgetLaunchAction { wait, signIn, openExpense }

abstract final class HomeWidgetLaunchPolicy {
  static bool accepts(Uri? uri) =>
      uri != null &&
      uri.scheme == 'cordato' &&
      uri.host == 'widget' &&
      uri.path == '/add-expense' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      uri.fragment.isEmpty &&
      uri.queryParametersAll.length == 1 &&
      uri.queryParametersAll['homeWidget']?.length == 1 &&
      uri.queryParameters['homeWidget'] == 'true';

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
