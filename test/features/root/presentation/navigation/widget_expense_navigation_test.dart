import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/navigation/widget_expense_navigation.dart';

void main() {
  group('Home widget expense navigation', () {
    for (final base in [
      RouteEnum.app,
      RouteEnum.informationHelp,
      RouteEnum.dashboard,
      RouteEnum.settings,
    ]) {
      test('opens Dashboard then creation from ${base.name}', () {
        final stack = [_route(base)];

        _open(stack);

        expect(stack.map((route) => route.uri.path), [
          RouteEnum.dashboard.path,
          RouteEnum.expense.path,
        ]);
        expect(stack.last.arguments, isNull);
      });
    }

    test('preserves the same Dashboard instance', () {
      final dashboard = _route(RouteEnum.dashboard);
      final stack = [dashboard];

      _open(stack);

      expect(stack.first, same(dashboard));
    });

    test('repeated taps preserve the same creation route and arguments', () {
      final creation = _route(
        RouteEnum.expense,
        arguments: (returnToPrevious: true),
      );
      final stack = [_route(RouteEnum.dashboard), creation];

      _open(stack);
      _open(stack);

      expect(stack, hasLength(2));
      expect(stack.last, same(creation));
      expect(stack.last.arguments, (returnToPrevious: true));
    });

    test(
      'brings an existing creation above other routes without replacing it',
      () {
        final creation = _route(RouteEnum.expense);
        final stack = [
          _route(RouteEnum.dashboard),
          creation,
          _route(RouteEnum.settings),
        ];

        _open(stack);

        expect(stack, hasLength(2));
        expect(stack.last, same(creation));
      },
    );

    test('does not mistake editing for creation', () {
      final editing = _route(RouteEnum.expense, arguments: 'expense-id');
      final stack = [_route(RouteEnum.dashboard), editing];

      _open(stack);

      expect(stack, hasLength(2));
      expect(stack.last, isNot(same(editing)));
      expect(stack.last.arguments, isNull);
    });

    test('removes unrelated history below a new creation', () {
      final stack = [_route(RouteEnum.settings), _route(RouteEnum.user)];

      _open(stack);
      stack.removeLast();

      expect(stack.single.uri.path, RouteEnum.dashboard.path);
    });
  });
}

RouteState _route(RouteEnum route, {Object? arguments}) =>
    RouteState(uri: Uri.parse(route.path), arguments: arguments);

void _open(List<RouteState> stack) {
  WidgetExpenseNavigation.open(
    baseRoute: stack.first,
    popUntil: (predicate) {
      while (stack.length > 1 && !predicate(stack.last)) {
        stack.removeLast();
      }
    },
    showDashboard: () {
      stack
        ..clear()
        ..add(_route(RouteEnum.dashboard));
    },
    pushExpense: () => stack.add(_route(RouteEnum.expense)),
  );
}
