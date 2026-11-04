import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/animations/collapsible_header_transition.dart';

void main() {
  group('Scroll-driven header transition', () {
    final scenarios = {
      -80.0: 0.0,
      0.0: 0.0,
      36.0: 0.25,
      72.0: 0.5,
      108.0: 0.75,
      144.0: 1.0,
      500.0: 1.0,
    };

    for (final entry in scenarios.entries) {
      test('scroll offset ${entry.key} produces fraction ${entry.value}', () {
        final transition = CollapsibleHeaderTransition.fromScroll(
          shrinkOffset: entry.key,
          expandedExtent: 200.0,
          collapsedExtent: 56.0,
        );

        expect(transition.fraction, entry.value);
        expect(
          transition.interpolate(expanded: 16.0, collapsed: 72.0),
          16.0 + 56.0 * entry.value,
        );
      });
    }

    test(
      'reverses continuously according to position, not scroll direction',
      () {
        final values = [
          for (final offset in [
            0.0,
            36.0,
            72.0,
            108.0,
            144.0,
            108.0,
            72.0,
            36.0,
            0.0,
          ])
            CollapsibleHeaderTransition.fromScroll(
              shrinkOffset: offset,
              expandedExtent: 200.0,
              collapsedExtent: 56.0,
            ).fraction,
        ];

        expect(values, [0.0, 0.25, 0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0]);
      },
    );

    test('interpolates positions and sizes in both directions', () {
      const transition = CollapsibleHeaderTransition(fraction: 0.25);

      expect(transition.interpolate(expanded: 80.0, collapsed: 16.0), 64.0);
      expect(transition.interpolate(expanded: 16.0, collapsed: 72.0), 30.0);
      expect(transition.interpolate(expanded: 32.0, collapsed: 22.0), 29.5);
    });

    final opacityScenarios = {
      0.0: 1.0,
      0.25: 0.5,
      0.5: 0.0,
      0.75: 0.0,
      1.0: 0.0,
    };
    for (final entry in opacityScenarios.entries) {
      test(
        'description opacity at fraction ${entry.key} is ${entry.value}',
        () {
          final transition = CollapsibleHeaderTransition(fraction: entry.key);

          expect(transition.descriptionOpacity, entry.value);
        },
      );
    }

    test('an extent change recalculates the fraction without stored state', () {
      final normal = CollapsibleHeaderTransition.fromScroll(
        shrinkOffset: 72.0,
        expandedExtent: 200.0,
        collapsedExtent: 56.0,
      );
      final enlarged = CollapsibleHeaderTransition.fromScroll(
        shrinkOffset: 72.0,
        expandedExtent: 344.0,
        collapsedExtent: 56.0,
      );

      expect(normal.fraction, 0.5);
      expect(enlarged.fraction, 0.25);
    });

    test('equal extents do not divide by zero', () {
      final transition = CollapsibleHeaderTransition.fromScroll(
        shrinkOffset: 0.0,
        expandedExtent: 56.0,
        collapsedExtent: 56.0,
      );

      expect(transition.fraction, 1.0);
      expect(transition.descriptionOpacity, 0.0);
      expect(transition.interpolate(expanded: 80.0, collapsed: 16.0), 16.0);
    });
  });

  group('Reduced motion', () {
    final scenarios = {
      -10.0: 0.0,
      0.0: 0.0,
      71.0: 0.0,
      72.0: 1.0,
      144.0: 1.0,
      200.0: 1.0,
    };

    for (final entry in scenarios.entries) {
      test(
        'offset ${entry.key} uses an endpoint instead of intermediate motion',
        () {
          final transition = CollapsibleHeaderTransition.fromScroll(
            shrinkOffset: entry.key,
            expandedExtent: 200.0,
            collapsedExtent: 56.0,
            reduceMotion: true,
          );

          expect(transition.fraction, entry.value);
          expect(
            transition.interpolate(expanded: 16.0, collapsed: 72.0),
            16.0 + 56.0 * entry.value,
          );
        },
      );
    }
  });
}
