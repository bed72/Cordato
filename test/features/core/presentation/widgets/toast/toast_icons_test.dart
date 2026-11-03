import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';

void main() {
  group('Toast animated icons', () {
    const icons = {
      ToastVariant.info: lucide.circle_help,
      ToastVariant.error: lucide.badge_alert,
      ToastVariant.success: lucide.circle_check,
      ToastVariant.warning: lucide.badge_alert,
    };

    for (final entry in icons.entries) {
      test('maps ${entry.key.name} to an animated Lucide icon', () {
        final icon = getToastIcon(entry.key);

        expect(icon, same(entry.value));
        expect(icon.elements, isNotEmpty);
        expect(
          icon.animation != null ||
              icon.elements.any((element) => element.animation != null),
          isTrue,
        );
      });
    }
  });
}
