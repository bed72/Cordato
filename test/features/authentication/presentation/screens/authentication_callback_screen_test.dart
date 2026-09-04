import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/animated_ellipsis_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/authentication_callback_screen.dart';

void main() {
  testWidgets('shows feedback while authentication is completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialPreviewWidget(child: AuthenticationCallbackScreen()),
    );

    expect(find.byType(AnimatedEllipsisWidget), findsOneWidget);
    expect(find.bySemanticsLabel('Validando acesso...'), findsOneWidget);
  });

  testWidgets('animates the dots sequentially and repeats the cycle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialPreviewWidget(child: AuthenticationCallbackScreen()),
    );

    double offsetFor(int index) {
      final transform = tester.widget<Transform>(
        find.byKey(ValueKey('animated-ellipsis-dot-$index')),
      );
      return transform.transform.storage[13];
    }

    await tester.pump(const Duration(milliseconds: 120));
    expect(offsetFor(0), lessThan(0.0));
    expect(offsetFor(1), 0.0);
    expect(offsetFor(2), 0.0);

    await tester.pump(const Duration(milliseconds: 280));
    expect(offsetFor(0), 0.0);
    expect(offsetFor(1), lessThan(0.0));
    expect(offsetFor(2), 0.0);

    await tester.pump(const Duration(milliseconds: 280));
    expect(offsetFor(0), 0.0);
    expect(offsetFor(1), 0.0);
    expect(offsetFor(2), lessThan(0.0));

    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 120));
    expect(offsetFor(0), lessThan(0.0));
  });
}
