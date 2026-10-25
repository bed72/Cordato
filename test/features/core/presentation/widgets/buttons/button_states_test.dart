import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/hold_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final theme in [Themes.light, Themes.dark]) {
    final colors = theme.extension<AppColors>()!;
    final variants = <String, Widget Function(VoidCallback?, bool)>{
      'elevated': (onTap, loading) => ElevatedButtonWidget(
        onTap: onTap,
        isLoading: loading,
        label: 'Continuar',
      ),
      'outline': (onTap, loading) => OutlineButtonWidget(
        onTap: onTap,
        isLoading: loading,
        label: 'Continuar',
      ),
      'text': (onTap, loading) => TextButtonWidget(
        onTap: onTap,
        isLoading: loading,
        label: 'Continuar',
      ),
      'danger': (onTap, loading) => DangerButtonWidget(
        onTap: onTap,
        isLoading: loading,
        label: 'Continuar',
      ),
      'hold': (onTap, loading) => HoldButtonWidget(
        onTap: onTap,
        isLoading: loading,
        label: 'Continuar',
      ),
    };

    for (final entry in variants.entries) {
      testWidgets('${theme.brightness} ${entry.key}: disabled keeps color', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: entry.value(null, false)),
          ),
        );
        final button = tester.widget<ButtonStyleButton>(
          find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        );
        expect(button.onPressed, isNull);
        final label = tester.element(find.text('Continuar'));
        final foreground = DefaultTextStyle.of(label).style.color;
        expect(foreground, switch (entry.key) {
          'danger' => colors.textOnError,
          'elevated' || 'hold' => colors.textOnPrimary,
          _ => Color.lerp(colors.primary, colors.surface, .25),
        });
        if (entry.key == 'elevated' ||
            entry.key == 'hold' ||
            entry.key == 'danger') {
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byWidgetPredicate(
                    (widget) => widget is ButtonStyleButton,
                  ),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(
            material.color,
            Color.lerp(
              entry.key == 'danger' ? colors.error : colors.primary,
              colors.surface,
              .25,
            ),
          );
        }
      });

      for (final callbackPresent in [false, true]) {
        testWidgets(
          '${theme.brightness} ${entry.key}: loading blocks taps ($callbackPresent)',
          (tester) async {
            var taps = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: entry.value(
                    callbackPresent ? () => taps++ : null,
                    true,
                  ),
                ),
              ),
            );
            final buttonFinder = find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            );
            final button = tester.widget<ButtonStyleButton>(buttonFinder);
            expect(button.onPressed, isNull);
            final spinner = tester.widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            );
            expect(spinner.valueColor!.value, switch (entry.key) {
              'danger' => colors.textOnError,
              'elevated' || 'hold' => colors.textOnPrimary,
              _ => colors.primary,
            });
            if (entry.key == 'elevated' ||
                entry.key == 'hold' ||
                entry.key == 'danger') {
              final material = tester.widget<Material>(
                find
                    .descendant(
                      of: buttonFinder,
                      matching: find.byType(Material),
                    )
                    .first,
              );
              expect(
                material.color,
                entry.key == 'danger'
                    ? colors.error.withValues(alpha: .9)
                    : colors.primary,
              );
            }
            await tester.tap(buttonFinder);
            await tester.pump(const Duration(milliseconds: 100));
            expect(taps, 0);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }

      testWidgets('${theme.brightness} ${entry.key}: enabled still works', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: entry.value(() => taps++, false)),
          ),
        );
        await tester.tap(find.text('Continuar'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(taps, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets(
      '${theme.brightness}: disabled link and icon retain their hue',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  const LinkButtonWidget(label: 'Voltar', onTap: null),
                  IconButtonWidget(
                    icon: Icons.add,
                    onPress: null,
                    iconColor: colors.primary,
                    backgroundColor: colors.surface,
                  ),
                ],
              ),
            ),
          ),
        );
        final disabledColor = Color.lerp(colors.primary, colors.surface, .25);
        expect(
          DefaultTextStyle.of(tester.element(find.text('Voltar'))).style.color,
          disabledColor,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.add)).color,
          disabledColor,
        );
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
      },
    );
  }
}
