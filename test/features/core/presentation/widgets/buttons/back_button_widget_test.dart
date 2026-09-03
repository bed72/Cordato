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
}
