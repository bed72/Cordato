import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';

void main() {
  group('Splash assets', () {
    for (final (asset, nativePath) in [
      (
        AssetEnum.splashAndroid,
        'android/app/src/main/res/drawable-xxxhdpi/launch_image.png',
      ),
      (
        AssetEnum.splashIos,
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
      ),
    ]) {
      test(
        '${asset.name} preserves the native image and transparent margins',
        () {
          final nativeImage = File(nativePath).readAsBytesSync();
          final flutterImage = File(asset.source).readAsBytesSync();

          expect(flutterImage, orderedEquals(nativeImage));
        },
      );

      test('${asset.name} is included in the Flutter bundle', () {
        final manifest = File('pubspec.yaml').readAsStringSync();

        expect(manifest, contains('- ${asset.source}'));
      });
    }
  });
}
