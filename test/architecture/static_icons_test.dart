import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'presentation uses static Material icons through the shared renderer',
    () {
      final violations = <String>[];
      const renderer =
          'lib/features/core/presentation/widgets/icons/icon_widget.dart';

      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (RegExp(
          r'flutter_lucide_animated|LucideAnimated|IconInteractionWidget|IconAnimationScopeWidget',
        ).hasMatch(source)) {
          violations.add('${file.path}: animated icon infrastructure');
        }
        if (file.path != renderer && RegExp(r'\bIcon\s*\(').hasMatch(source)) {
          violations.add('${file.path}: bypasses the shared icon renderer');
        }
      }

      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('flutter_lucide_animated')),
      );
      final rendererSource = File(renderer).readAsStringSync();
      expect(rendererSource, contains('extends StatelessWidget'));
      expect(rendererSource, isNot(contains('AnimationController')));
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
