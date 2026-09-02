import 'package:cordato/app_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the app root route', (tester) async {
    final testModule = createModule(
      register: (c) {
        c.route('/', child: (_, _) => const Text('Test route'));
      },
    );

    await tester.pumpWidget(
      ModularApp(module: testModule, child: const AppWidget()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test route'), findsOneWidget);
  });
}
