import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Local runtime configuration', () {
    test(
      'Android release declares no network, microphone or authentication links',
      () {
        final manifest = File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync();

        expect(manifest, isNot(contains('android.permission.INTERNET')));
        expect(manifest, isNot(contains('android.permission.RECORD_AUDIO')));
        expect(manifest, isNot(contains('authentication')));
        expect(manifest, isNot(contains('android:autoVerify')));
        expect(manifest, contains('android:label="@string/label_app_name"'));
      },
    );

    test(
      'iOS retains the widget scheme without microphone or associated domains',
      () {
        final runner = File('ios/Runner/Info.plist').readAsStringSync();
        final entitlements = File('ios/Runner/Runner.entitlements')
            .readAsStringSync();

        expect(runner, contains('<string>cordato</string>'));
        expect(runner, isNot(contains('NSMicrophoneUsageDescription')));
        expect(runner, isNot(contains('<string>trocado</string>')));
        expect(entitlements, contains('group.com.bed.cordato'));
        expect(
          entitlements,
          isNot(contains('com.apple.developer.associated-domains')),
        );
      },
    );

    test(
      'Android release workflow does not inject legacy backend configuration',
      () {
        final workflow = File('.github/workflows/android-release.yml')
            .readAsStringSync();

        expect(workflow, isNot(contains('BASE_URL')));
        expect(workflow, isNot(contains('pocketbase.cordato.cloud')));
      },
    );
  });
}
