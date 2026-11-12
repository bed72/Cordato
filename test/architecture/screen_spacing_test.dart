import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('screen spacing', () {
    final presentationFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('/previews/'));

    for (final file in presentationFiles) {
      final source = file.readAsStringSync();

      if (!source.contains('leadingWidth:')) {
        continue;
      }

      test('${file.path} reserves symmetric space for back navigation', () {
        final leadingWidths = RegExp(r'leadingWidth:\s*([\d.]+)')
            .allMatches(source);

        expect(leadingWidths, isNotEmpty);
        for (final width in leadingWidths) {
          expect(double.parse(width.group(1)!), 48.0 + 16.0 * 2.0);
        }
        expect(
          RegExp(r'leading:\s*Padding\(\s*padding:[^\n]*only\(')
              .hasMatch(source),
          isFalse,
        );
      });
    }

    test('expanded headers use the same title inset as fixed headers', () {
      final header = File(
        'lib/features/core/presentation/widgets/headers/collapsible_header_widget.dart',
      ).readAsStringSync();
      final delegate = File(
        'lib/features/core/presentation/widgets/headers/collapsible_header_delegate.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'collapsedExtent\s*\+\s*16\.0\s*\+').hasMatch(header),
        isTrue,
      );
      expect(delegate, contains('expanded: minExtent + 16.0'));
      expect(delegate, contains('start: 16.0'));
      expect(delegate, contains('collapsed: 80.0'));
      expect(header, contains('width - 96.0'));
    });

    for (final path in [
      'dashboard/presentation/widgets/dashboard_month_selector_widget.dart',
      'dashboard/presentation/widgets/expenses/expenses_section_widget.dart',
      'dashboard/presentation/widgets/metrics/metrics_section_widget.dart',
      'expense/presentation/screens/expenses/widgets/expenses_filters_widget.dart',
    ]) {
      test('$path aligns content with the screen edges', () {
        final source = File('lib/features/$path').readAsStringSync();
        final horizontalInsets = RegExp(r'horizontal:\s*([\d.]+)')
            .allMatches(source);

        expect(horizontalInsets, isNotEmpty);
        for (final inset in horizontalInsets) {
          expect(double.parse(inset.group(1)!), 16.0);
        }
      });
    }

    test('carousel page geometry preserves a 16 pixel outer inset', () {
      final carousel = File(
        'lib/features/metrics/presentation/widgets/expense_metrics_carousel_widget.dart',
      ).readAsStringSync();
      final lifecycle = File(
        'lib/features/metrics/presentation/mixins/expense_metrics_carousel_widget_state_mixin.dart',
      ).readAsStringSync();
      final viewportReduction = double.parse(
        RegExp(r'\(width - ([\d.]+)\)').firstMatch(lifecycle)!.group(1)!,
      );
      final pagePadding = double.parse(
        RegExp(r'horizontal:\s*([\d.]+)').firstMatch(carousel)!.group(1)!,
      );
      final contentReduction = double.parse(
        RegExp(r'constraints.maxWidth - ([\d.]+)')
            .firstMatch(carousel)!
            .group(1)!,
      );

      expect(viewportReduction / 2.0 + pagePadding, 16.0);
      expect(contentReduction, viewportReduction + pagePadding * 2.0);
    });
  });
}
