import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_typewriter.dart';

void main() {
  TextSpan rootSpan(WidgetTester tester) =>
      tester.widget<RichText>(find.byType(RichText)).text as TextSpan;

  TextSpan contentSpan(WidgetTester tester) =>
      rootSpan(tester).children!.single as TextSpan;

  TextSpan phraseSpan(WidgetTester tester) =>
      contentSpan(tester).children!.first as TextSpan;

  TextSpan cursorSpan(WidgetTester tester) =>
      contentSpan(tester).children!.last as TextSpan;

  String renderedText(WidgetTester tester) => phraseSpan(tester).text!;

  bool isCursorVisible(WidgetTester tester) =>
      cursorSpan(tester).style!.color != Colors.transparent;

  Future<void> pumpTypewriter(WidgetTester tester, List<String> phrases) async {
    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: WelcomeTypewriterWidget(color: Colors.black, phrases: phrases),
      ),
    );
  }

  testWidgets('renders the phrase received through its parameter', (
    tester,
  ) async {
    await pumpTypewriter(tester, const ['teste']);
    await tester.pump(const Duration(milliseconds: 400));

    expect(renderedText(tester), 'teste');
    expect(isCursorVisible(tester), isTrue);
  });

  testWidgets('blinks the cursor four times before erasing the phrase', (
    tester,
  ) async {
    await pumpTypewriter(tester, const ['a']);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1400));

    expect(renderedText(tester), 'a');
    expect(isCursorVisible(tester), isFalse);

    for (var blink = 0; blink < 3; blink++) {
      await tester.pump(const Duration(milliseconds: 250));
      expect(isCursorVisible(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 250));
      expect(isCursorVisible(tester), isFalse);
    }

    await tester.pump(const Duration(milliseconds: 300));
    expect(renderedText(tester), '');
    expect(isCursorVisible(tester), isTrue);
  });
}
