import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import '../../tool/app_links.dart';

void main() {
  const host = 'app.cordato.cloud';
  const package = 'com.bed.cordato';
  final path = RouteEnum.authenticationConfirmEmail.path;

  test('Android verifies the HTTPS verification route', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final resources = File('android/app/src/main/res/values/strings.xml')
        .readAsStringSync();

    expect(manifest, contains('android:autoVerify="true"'));
    for (final name in ['scheme', 'host', 'path']) {
      expect(manifest, contains('@string/confirm_email_$name'));
    }
    expect(
      resources,
      contains('<string name="confirm_email_scheme">https</string>'),
    );
    expect(
      resources,
      contains('<string name="confirm_email_host">$host</string>'),
    );
    expect(
      resources,
      contains('<string name="confirm_email_path">$path</string>'),
    );
  });

  test('iOS associates the domain in every Runner build configuration', () {
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();

    expect(entitlements, contains('com.apple.developer.associated-domains'));
    expect(entitlements, contains('<string>applinks:$host</string>'));
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'.allMatches(
        project,
      ),
      hasLength(3),
    );
    expect(
      'PRODUCT_BUNDLE_IDENTIFIER = $package;'.allMatches(project),
      hasLength(3),
    );
  });

  test(
    'public associations match the callback route and native identifiers',
    () {
      final files = associationFiles(
        appleAppId: 'ABCDEFGHIJ.$package',
        androidSha256: [List.filled(32, 'AB').join(':')],
      );
      final apple = jsonDecode(files['apple-app-site-association']!) as Map;
      final android = jsonDecode(files['assetlinks.json']!) as List;
      final details = (apple['applinks'] as Map)['details'] as List;

      expect((details.single as Map)['components'], [
        {'/': path},
      ]);
      expect(
        ((android.single as Map)['target'] as Map)['package_name'],
        package,
      );
    },
  );
}
