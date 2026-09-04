import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

void main() {
  testWidgets('renders a subtle diagonal background gradient', (tester) async {
    await tester.pumpWidget(
      MaterialPreviewWidget(child: BackButtonWidget(onPress: () {})),
    );

    final background = tester.widget<BackgroundIconWidget>(
      find.byType(BackgroundIconWidget),
    );
    final gradient = background.gradient! as LinearGradient;

    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors, [
      Themes.light.colorScheme.surfaceDim,
      Themes.light.colorScheme.surface,
    ]);
  });

  testWidgets('dismisses the keyboard before handling press', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var pressed = false;

    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focusNode, autofocus: true),
              BackButtonWidget(onPress: () => pressed = true),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byType(BackButtonWidget));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(pressed, isTrue);
  });
}
