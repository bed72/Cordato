import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/screens/authentication_callback_screen.dart';
import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';

void main() {
  testWidgets('shows feedback while authentication is completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialPreviewWidget(child: AuthenticationCallbackScreen()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Validando acesso...'), findsOneWidget);
  });
}
