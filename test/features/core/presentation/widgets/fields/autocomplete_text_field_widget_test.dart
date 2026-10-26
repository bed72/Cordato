import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/fields/autocomplete_text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

void main() {
  late TextEditingController controller;
  late List<String> selections;
  late int submitted;
  late int calls;
  late FutureOr<Iterable<String>> Function(TextEditingValue) lookup;

  setUp(() {
    controller = TextEditingController();
    selections = [];
    submitted = 0;
    calls = 0;
    lookup = (_) => const [];
  });

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Themes.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: AutocompleteTextFieldWidget<String>(
                label: 'Descrição',
                hint: 'Ex: Mercado',
                controller: controller,
                enabled: enabled,
                optionsBuilder: (value) {
                  calls++;
                  return lookup(value);
                },
                displayStringForOption: (option) => option,
                onSelected: selections.add,
                onInvalidated: () {},
                onSubmitted: (_) => submitted++,
                optionsViewBuilder: (context, select, options) => Material(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final option in options)
                        ListTile(
                          title: Text(option),
                          onTap: () => select(option),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.text = 'still owned externally';
    controller.dispose();
    expect(tester.takeException(), isNull);
  }

  testWidgets('uses shared field and submits free text immediately', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(TextFieldWidget), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Novo');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(submitted, 1);
    expect(controller.text, 'Novo');
    await finish(tester);
  });

  testWidgets('async result appears with stable text and Enter selects once', (
    tester,
  ) async {
    final pending = Completer<Iterable<String>>();
    lookup = (value) => value.text.isEmpty ? const [] : pending.future;
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Mer');
    await tester.pump();
    pending.complete(['Mercado']);
    await tester.pump();
    await tester.pump();
    expect(find.text('Mercado'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(selections, ['Mercado']);
    expect(submitted, 0);
    expect(controller.text, 'Mercado');
    await finish(tester);
  });

  testWidgets('old result cannot be selected while newer query is pending', (
    tester,
  ) async {
    final pending = Completer<Iterable<String>>();
    lookup = (value) => value.text == 'Mer' ? ['Mercado'] : pending.future;
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Mer');
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alu');
    await tester.pump();
    expect(find.text('Mercado'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(selections, isEmpty);
    expect(submitted, 1);
    pending.complete(['Aluguel']);
    await tester.pump();
    await finish(tester);
  });

  testWidgets(
    'IME composition waits for commit without changing visible text',
    (tester) async {
      lookup = (_) => ['Mercado'];
      await pump(tester);
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      final before = calls;
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Mer',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
      );
      await tester.pump();
      expect(calls, before);
      expect(controller.text, 'Mer');
      expect(controller.value.composing, const TextRange(start: 0, end: 3));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Mer',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
      expect(find.text('Mercado'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets('clearing and disposal cannot resurrect asynchronous results', (
    tester,
  ) async {
    final pending = Completer<Iterable<String>>();
    lookup = (value) => value.text.isEmpty ? const [] : pending.future;
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Mer');
    await tester.pump();
    controller.clear();
    await tester.pump();
    pending.complete(['Mercado']);
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsNothing);
    final after = Completer<Iterable<String>>();
    lookup = (_) => after.future;
    await tester.enterText(find.byType(TextField), 'Alu');
    await tester.pump();
    await finish(tester);
    after.complete(['Aluguel']);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disable and disposal suppress pending options', (tester) async {
    final pending = Completer<Iterable<String>>();
    lookup = (_) => pending.future;
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Mer');
    await tester.pump();
    await pump(tester, enabled: false);
    pending.complete(['Mercado']);
    await tester.pump();
    expect(find.text('Mercado'), findsNothing);
    await finish(tester);
  });

  testWidgets('cursor movement does not query, refocus refreshes same text', (
    tester,
  ) async {
    lookup = (_) => ['Mercado'];
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Mer');
    await tester.pumpAndSettle();
    final before = calls;
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    expect(calls, before);
    tester.widget<TextField>(find.byType(TextField)).focusNode!.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
    expect(find.text('Mercado'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Mercado'), findsNothing);
    await finish(tester);
  });
}
