import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/notification_button_dashboard_widget.dart';

void main() {
  testWidgets('renders the back button background and invokes its callback', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: NotificationButtonDashboardWidget(onPress: () => pressed = true),
      ),
    );

    final background = tester.widget<BackgroundIconWidget>(
      find.byType(BackgroundIconWidget),
    );
    final gradient = background.gradient! as LinearGradient;

    expect(find.bySemanticsLabel('Notificações'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(background.iconSize, 26.0);
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors, [
      Color.lerp(
        Themes.light.colorScheme.surfaceDim,
        Themes.light.colorScheme.onSurface,
        .0,
      ),
      Color.lerp(
        Themes.light.colorScheme.surface,
        Themes.light.colorScheme.onSurface,
        .06,
      ),
    ]);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));

    expect(pressed, isTrue);
  });
}
