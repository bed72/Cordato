import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';

void main() {
  group('Toast Material icons', () {
    const icons = {
      ToastVariant.info: Icons.help_outline,
      ToastVariant.error: Icons.warning_amber_rounded,
      ToastVariant.success: Icons.check_circle_outline,
      ToastVariant.warning: Icons.warning_amber_rounded,
    };

    for (final entry in icons.entries) {
      test('maps ${entry.key.name} to a static Material icon', () {
        final icon = getToastIcon(entry.key);

        expect(icon, same(entry.value));
        expect(icon.fontFamily, 'MaterialIcons');
      });
    }
  });
}
