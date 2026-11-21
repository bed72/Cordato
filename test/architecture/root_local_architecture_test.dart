import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap opens Dashboard after awaiting local dependencies', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('await createDependencies()'));
    expect(source, contains('initialRoute: RouteEnum.dashboard.path'));
    expect(source, isNot(contains('SessionBloc')));
  });

  test('Root has no session or authentication routing dependency', () {
    final retiredDependency = RegExp(
      r'features/(?:authentication|session)/|SessionBloc|SessionRedirect|SessionRoutePolicy|HomeWidgetLaunchPolicy|authenticationSignIn',
    );
    for (final file
        in Directory('lib/features/root')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      expect(
        retiredDependency.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('AppWidget owns only stable launch and sync Bloc factories', () {
    final widget = File(
      'lib/features/root/presentation/widgets/app_widget.dart',
    ).readAsStringSync();
    final lifecycle = File(
      'lib/features/root/presentation/mixins/app_widget_state_mixin.dart',
    ).readAsStringSync();

    expect(widget, contains('HomeWidgetSyncBloc Function()'));
    expect(widget, contains('HomeWidgetLaunchBloc Function()'));
    expect(widget, contains('ToastProviderWidget'));
    expect(
      lifecycle,
      contains('oldWidget.homeWidgetLaunchBloc != widget.homeWidgetLaunchBloc'),
    );
    expect(
      lifecycle,
      contains('oldWidget.homeWidgetSyncBloc != widget.homeWidgetSyncBloc'),
    );
    expect(lifecycle, contains('unawaited(homeWidgetLaunchBloc.close())'));
    expect(lifecycle, contains('unawaited(homeWidgetSyncBloc.close())'));
    expect(lifecycle, isNot(contains('.listen(')));
    expect(lifecycle, isNot(contains('IHomeWidgetClient')));
  });

  test('navigation waits for the navigator and protects disposed or replaced owners', () {
    final lifecycle = File(
      'lib/features/root/presentation/mixins/app_widget_state_mixin.dart',
    ).readAsStringSync();

    expect(lifecycle, contains('addPostFrameCallback'));
    expect(lifecycle, contains('!mounted'));
    expect(lifecycle, contains('homeWidgetLaunchBloc != owner'));
    expect(lifecycle, contains('owner.isClosed'));
    expect(lifecycle, contains('widget.navigatorKey != key'));
    expect(lifecycle, contains('if (target == null)'));
    expect(lifecycle, contains('AppNavigationPolicy.action'));
    expect(lifecycle, contains('HomeWidgetExpenseNavigation.open'));
  });
}
