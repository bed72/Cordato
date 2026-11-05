import 'dart:io';
import 'dart:convert';

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
    final resources = File(
      'android/app/src/main/res/values/strings_authentication.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:autoVerify="true"'));
    for (final name in ['link_scheme', 'link_host', 'confirm_email_path']) {
      expect(manifest, contains('@string/config_authentication_$name'));
    }
    expect(
      resources,
      contains(
        '<string name="config_authentication_link_scheme" translatable="false">https</string>',
      ),
    );
    expect(
      resources,
      contains(
        '<string name="config_authentication_link_host" translatable="false">$host</string>',
      ),
    );
    expect(
      resources,
      contains(
        '<string name="config_authentication_confirm_email_path" translatable="false">$path</string>',
      ),
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
        {'/': RouteEnum.authenticationResetPassword.path},
      ]);
      expect(
        ((android.single as Map)['target'] as Map)['package_name'],
        package,
      );
    },
  );

  test('Android verifies the exact HTTPS password reset route', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final resources = File(
      'android/app/src/main/res/values/strings_authentication.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains(
        'android:path="@string/config_authentication_reset_password_path"',
      ),
    );
    expect(
      resources,
      contains(
        '<string name="config_authentication_reset_password_path" translatable="false">${RouteEnum.authenticationResetPassword.path}</string>',
      ),
    );
  });
}
