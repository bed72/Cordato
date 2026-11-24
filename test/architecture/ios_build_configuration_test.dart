import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS project and widget require iOS 16 in all configurations', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final minimumVersions = RegExp(
      r'\bIPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);',
    ).allMatches(project).map((match) => match.group(1)!.trim());

    expect(minimumVersions, List.filled(6, '16.0'));
  });
}
