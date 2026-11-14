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

    test(
      'category cards preserve symmetric insets and single-line amounts',
      () {
        final card = File(
          'lib/features/metrics/presentation/widgets/expense_category_card_widget.dart',
        ).readAsStringSync();

        expect(card, contains('padding: const .all(16.0)'));
        expect(card, contains('const Spacer()'));
        expect(card, contains('fit: .scaleDown'));
        expect(
          RegExp(r'alignment:\s*(?:Alignment)?\.bottomLeft').hasMatch(card),
          isTrue,
        );
        expect(card, contains('fontSize: 16.0'));
        expect(card, isNot(contains('fontSize: highlighted')));
        expect(
          RegExp(r'Text\(\s*amount,\s*maxLines: 1,\s*softWrap: false,')
              .hasMatch(card),
          isTrue,
        );
        expect(card, isNot(contains('LayoutBuilder(')));
      },
    );

    test('category row height is not stretched by a tip on another page', () {
      final grid = File(
        'lib/features/metrics/presentation/widgets/expense_metrics_grid_widget.dart',
      ).readAsStringSync();
      final carousel = File(
        'lib/features/metrics/presentation/widgets/expense_metrics_carousel_widget.dart',
      ).readAsStringSync();

      expect(grid, contains('final bottomHeight = layout.lowerHeight;'));
      expect(grid, isNot(contains('final double? lowerHeight')));
      expect(carousel, isNot(contains('lowerHeight: lowerHeight')));
    });

    test('tip uses a compact header and at least the category card height', () {
      final tip = File(
        'lib/features/metrics/presentation/widgets/expense_metrics_tip_card_widget.dart',
      ).readAsStringSync();
      final grid = File(
        'lib/features/metrics/presentation/widgets/expense_metrics_grid_widget.dart',
      ).readAsStringSync();

      expect(tip, contains('Row('));
      expect(tip, contains('Toque em uma categoria para ver os gastos.'));
      expect(tip, contains('padding: const .all(16.0)'));
      expect(tip, contains('const Spacer()'));
      expect(tip, contains('fit: .scaleDown'));
      expect(
        RegExp(r'alignment:\s*(?:Alignment)?\.bottomLeft').hasMatch(tip),
        isTrue,
      );
      expect(
        RegExp(r'Text\(\s*_description,\s*maxLines: 1,\s*softWrap: false,')
            .hasMatch(tip),
        isTrue,
      );
      expect(tip, contains('const SizedBox(width: 12.0)'));
      expect(tip, contains('width: math.max(1.0, contentWidth - 52.0)'));
      expect(tip, isNot(contains('const SizedBox(height: 20.0)')));
      expect(
        RegExp(r'hasCategoryTip\s*\? math.max\(\s*topHeight,').hasMatch(grid),
        isTrue,
      );
    });

    test('pager follows the current page with a 24 pixel gap', () {
      final carousel = File(
        'lib/features/metrics/presentation/widgets/expense_metrics_carousel_widget.dart',
      ).readAsStringSync();

      expect(carousel, contains('layouts[currentPage].lowerHeight'));
      expect(
        RegExp(r'return Column\(\s*spacing: 24\.0,').hasMatch(carousel),
        isTrue,
      );
      expect(carousel, isNot(contains('padding: const .only(top: 8.0)')));
      expect(
        RegExp(r'alignment:\s*(?:Alignment)?\.topCenter').hasMatch(carousel),
        isTrue,
      );
      expect(
        RegExp(r'maxHeight:\s*(?:double)?\.infinity').hasMatch(carousel),
        isTrue,
      );
    });

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
