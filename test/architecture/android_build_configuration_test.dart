import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android requires Android 12 independently of the Flutter default', () {
    final app = File('android/app/build.gradle.kts').readAsStringSync();
    final minimumVersions = RegExp(r'\bminSdk\s*=\s*([^;\r\n]+)')
        .allMatches(app)
        .map((match) => match.group(1)!.trim());

    expect(minimumVersions, ['31']);
  });

  test(
    'Android uses built-in Kotlin without applying external KGP to the app',
    () {
      final properties = File('android/gradle.properties').readAsStringSync();
      final app = File('android/app/build.gradle.kts').readAsStringSync();

      expect(properties, contains('android.builtInKotlin=true'));
      expect(app, isNot(contains('id("kotlin-android")')));
      expect(app, isNot(contains('id("org.jetbrains.kotlin.android")')));
    },
  );

  test('both wrapper launchers grant the native access required by Gradle', () {
    final unix = File('android/gradlew').readAsStringSync();
    final windows = File('android/gradlew.bat').readAsStringSync();
    final properties = File('android/gradle.properties').readAsStringSync();

    expect(
      unix,
      contains('DEFAULT_JVM_OPTS="--enable-native-access=ALL-UNNAMED"'),
    );
    expect(
      windows,
      contains('set DEFAULT_JVM_OPTS=--enable-native-access=ALL-UNNAMED'),
    );
    expect(properties, contains('--enable-native-access=ALL-UNNAMED'));
  });
}
