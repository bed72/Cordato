import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';

void main() {
  for (final asset in AssetEnum.values) {
    test('${asset.name} references an existing local asset', () {
      expect(File(asset.source).existsSync(), isTrue, reason: asset.source);
      expect(asset.alt, isNotEmpty);
    });
  }
}
