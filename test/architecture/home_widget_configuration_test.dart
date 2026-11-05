import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/root/presentation/navigation/home_widget_launch_policy.dart';

void main() {
  test('both native widgets launch the exact supported action', () {
    for (final path in [
      'android/app/src/main/kotlin/com/bed/cordato/AddExpenseWidgetProvider.kt',
      'ios/AddExpenseWidget/AddExpenseWidget.swift',
    ]) {
      final source = File(path).readAsStringSync();
      final address = RegExp(r'cordato://[^"\s]+')
          .firstMatch(source)!
          .group(0)!;

      expect(HomeWidgetLaunchPolicy.accepts(Uri.parse(address)), isTrue);
    }
  });

  test('Android registers the provider without periodic background work', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final provider = File(
      'android/app/src/main/res/xml/add_expense_widget_info.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".AddExpenseWidgetProvider"'));
    expect(
      manifest,
      contains('android:resource="@xml/add_expense_widget_info"'),
    );
    expect(provider, contains('android:updatePeriodMillis="0"'));
    expect(provider, contains('android:widgetCategory="home_screen"'));
  });

  test(
    'Android widget launches do not replace the Flutter route via deep linking',
    () {
      final activity = File(
        'android/app/src/main/kotlin/com/bed/cordato/MainActivity.kt',
      ).readAsStringSync();

      expect(activity, contains('override fun shouldHandleDeeplinking()'));
      expect(
        activity,
        contains(
          'intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION',
        ),
      );
      expect(activity, contains('super.shouldHandleDeeplinking()'));
      expect(activity, contains('setIntent(intent)'));
    },
  );

  test('iOS has an embedded WidgetKit target and registers the URL scheme', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final extension = File('ios/AddExpenseWidget/Info.plist')
        .readAsStringSync();
    final runner = File('ios/Runner/Info.plist').readAsStringSync();

    expect(project, contains('name = "Embed App Extensions";'));
    expect(
      project,
      contains('productType = "com.apple.product-type.app-extension";'),
    );
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.bed.cordato.AddExpenseWidget;'),
    );
    expect(extension, contains('com.apple.widgetkit-extension'));
    expect(runner, contains('<string>cordato</string>'));
  });
}
