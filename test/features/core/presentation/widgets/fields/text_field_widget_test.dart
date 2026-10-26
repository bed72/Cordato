import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    TextEditingController? controller,
    FocusNode? focus,
    String? initialValue,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: Themes.light,
      home: Scaffold(
        body: TextFieldWidget(
          hint: 'Descrição',
          label: 'Descrição',
          controller: controller,
          focusNode: focus,
          initialValue: initialValue,
        ),
      ),
    ),
  );

  testWidgets(
    'external focus and controller can be replaced without being disposed',
    (tester) async {
      final first = TextEditingController(text: 'Primeiro');
      final second = TextEditingController(text: 'Segundo');
      final firstFocus = FocusNode();
      final secondFocus = FocusNode();
      await pump(tester, controller: first, focus: firstFocus);
      firstFocus.requestFocus();
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(firstFocus),
      );
      await pump(tester, controller: second, focus: secondFocus);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(second),
      );
      first.text = 'Detached';
      firstFocus.requestFocus();
      await tester.pump();
      expect(find.text('Segundo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      first.text = 'Alive';
      second.text = 'Alive';
      first.dispose();
      second.dispose();
      firstFocus.dispose();
      secondFocus.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'owned controller preserves input on rebuild and transfers when external is removed',
    (tester) async {
      await pump(tester, initialValue: 'Initial');
      await tester.enterText(find.byType(TextField), 'Typed');
      await pump(tester, initialValue: 'Initial');
      expect(find.text('Typed'), findsOneWidget);
      final external = TextEditingController(text: 'External');
      await pump(tester, controller: external);
      await pump(tester);
      expect(find.text('External'), findsOneWidget);
      external.text = 'Detached';
      expect(find.text('External'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      external.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
