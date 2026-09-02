import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

void main() {
  testWidgets('renders the icon with its background and handles press', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: IconButtonWidget(
          icon: Icons.arrow_back,
          onPress: () => pressed = true,
          backgroundColor: Colors.transparent,
        ),
      ),
    );

    expect(find.byType(BackgroundIconWidget), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is BounceWidget),
      findsWidgets,
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump(const Duration(milliseconds: 30));

    expect(pressed, isTrue);
  });
}
