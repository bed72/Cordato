import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('custom motion respects Android and iOS accessibility preferences', () {
    for (final path in [
      'lib/features/core/presentation/widgets/bounce_widget.dart',
      'lib/features/core/presentation/widgets/headers/collapsible_header_widget.dart',
      'lib/features/core/presentation/widgets/toast/toast_provider_widget.dart',
      'lib/features/authentication/presentation/screens/resend_email/widgets/resend_email_cooldown_label_widget.dart',
      'lib/features/dashboard/presentation/widgets/audio_waveform_widget.dart',
      'lib/features/dashboard/presentation/widgets/metrics/animated_expense_total_widget.dart',
      'lib/features/dashboard/presentation/widgets/mixins/dashboard_audio_state_mixin.dart',
    ]) {
      test(path, () {
        final source = File(path).readAsStringSync();

        expect(
          source,
          matches(
            RegExp(
              r'MediaQuery\.disableAnimationsOf\(context\)\s*\|\|\s*'
              r'MediaQuery\.reduceMotionOf\(context\)',
            ),
          ),
        );
      });
    }
  });
}
