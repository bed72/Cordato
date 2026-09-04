import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';

void main() {
  testWidgets('renders the dashboard', (tester) async {
    await tester.pumpWidget(
      const MaterialPreviewWidget(child: DashboardScreen()),
    );

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
