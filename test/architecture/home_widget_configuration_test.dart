import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/root/infrastructure/serializers/home_widget_launch_serializer.dart';

void main() {
  test('iOS shares only the monthly cache through the same App Group in both targets', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/AddExpenseWidget/AddExpenseWidget.entitlements',
    ]) {
      final entitlements = File(path).readAsStringSync();
      expect(entitlements, contains('com.apple.security.application-groups'));
      expect(entitlements, contains('group.com.bed.cordato'));
    }
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(
      'CODE_SIGN_ENTITLEMENTS = AddExpenseWidget/AddExpenseWidget.entitlements;'
          .allMatches(project),
      hasLength(3),
    );
    expect(project, contains('path = AddExpenseProvider.swift;'));
  });

  test('native monthly renderers reject mismatched months and retain integer precision', () {
    final android = File(
      'android/app/src/main/kotlin/com/bed/cordato/AddExpenseWidgetProvider.kt',
    ).readAsStringSync();
    final ios = File('ios/AddExpenseWidget/AddExpenseProvider.swift')
        .readAsStringSync();
    final androidMoney = File(
      'android/app/src/main/kotlin/com/bed/cordato/WidgetPresentation.kt',
    ).readAsStringSync();
    final iosMoney = File('ios/AddExpenseWidget/WidgetPresentation.swift')
        .readAsStringSync();

    expect(iosMoney, contains('cents.magnitude / 100'));
    expect(iosMoney, contains('cents.magnitude % 100'));
    expect(iosMoney, isNot(contains('Double(cents)')));
    expect(ios, contains('entry(at: nextMonth)'));
    expect(android, contains('nextMonthStartMillis()'));
    expect(androidMoney, contains('BigDecimal.valueOf(cents, 2)'));
    expect(ios, contains('summary.month == monthKey(for: date)'));
    expect(android, contains('snapshot.optString("month") != monthKey'));
  });

  test('both native widgets launch the exact supported action', () {
    for (final path in [
      'android/app/src/main/kotlin/com/bed/cordato/AddExpenseWidgetProvider.kt',
      'ios/AddExpenseWidget/AddExpenseWidget.swift',
    ]) {
      final source = File(path).readAsStringSync();
      final address = RegExp(r'cordato://[^"\s]+')
          .firstMatch(source)!
          .group(0)!;

      expect(isHomeWidgetExpenseLaunch(Uri.parse(address)), isTrue);
    }
  });

  test('Android registers the provider without periodic background work', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final provider = File(
      'android/app/src/main/res/xml/add_expense_widget_info.xml',
    ).readAsStringSync();

    expect(provider, contains('android:updatePeriodMillis="0"'));
    expect(provider, contains('android:widgetCategory="home_screen"'));
    expect(manifest, contains('android:name=".AddExpenseWidgetProvider"'));
    expect(
      manifest,
      contains('android:resource="@xml/add_expense_widget_info"'),
    );
  });

  test('Android supports resizing and refreshes each widget when its options change', () {
    final configuration = File(
      'android/app/src/main/res/xml/add_expense_widget_info.xml',
    ).readAsStringSync();
    final provider = File(
      'android/app/src/main/kotlin/com/bed/cordato/AddExpenseWidgetProvider.kt',
    ).readAsStringSync();

    expect(configuration, contains('android:resizeMode="horizontal|vertical"'));
    expect(configuration, contains('android:minResizeWidth="150dp"'));
    expect(configuration, contains('android:minResizeHeight="56dp"'));
    expect(provider, contains('override fun onAppWidgetOptionsChanged('));
    expect(
      provider,
      contains('onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))'),
    );
    expect(
      provider,
      contains('appWidgetManager.getAppWidgetOptions(widgetId)'),
    );
    expect(provider, contains('AppWidgetManager.OPTION_APPWIDGET_SIZES'));
  });

  test('native month formatters preserve Brazilian capitalization', () {
    final android = File(
      'android/app/src/main/kotlin/com/bed/cordato/AddExpenseWidgetProvider.kt',
    ).readAsStringSync();
    final ios = File('ios/AddExpenseWidget/AddExpenseProvider.swift')
        .readAsStringSync();

    expect(
      android,
      contains('replaceFirstChar { it.titlecase(brazilianLocale) }'),
    );
    expect(ios, contains('capitalized(with: brazilianLocale)'));
  });

  test(
    'Android widget launches do not replace the Flutter route via deep linking',
    () {
      final activity = File(
        'android/app/src/main/kotlin/com/bed/cordato/MainActivity.kt',
      ).readAsStringSync();

      expect(activity, contains('setIntent(intent)'));
      expect(activity, contains('super.shouldHandleDeeplinking()'));
      expect(activity, contains('override fun shouldHandleDeeplinking()'));
      expect(
        activity,
        contains(
          'intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION',
        ),
      );
    },
  );

  test('iOS has an embedded WidgetKit target and registers the URL scheme', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final extension = File('ios/AddExpenseWidget/Info.plist')
        .readAsStringSync();
    final runner = File('ios/Runner/Info.plist').readAsStringSync();
    final widget = File('ios/AddExpenseWidget/AddExpenseWidget.swift')
        .readAsStringSync();

    expect(runner, contains('<string>cordato</string>'));
    expect(project, contains('name = "Embed App Extensions";'));
    expect(extension, contains('com.apple.widgetkit-extension'));
    expect(
      widget,
      contains('.supportedFamilies([.systemSmall, .systemMedium])'),
    );
    expect(project, contains('path = WidgetPresentation.swift;'));
    expect(project, contains('path = WidgetSummaryView.swift;'));
    expect(project, contains('path = WidgetActionView.swift;'));
    expect(project, contains('path = WidgetRenderedActionView.swift;'));
    expect(widget, contains('@Environment(\\.widgetFamily)'));
    expect(widget, contains('family == .systemMedium ? .medium : .small'));
    expect(
      project,
      contains('productType = "com.apple.product-type.app-extension";'),
    );
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.bed.cordato.AddExpenseWidget;'),
    );
  });
}
