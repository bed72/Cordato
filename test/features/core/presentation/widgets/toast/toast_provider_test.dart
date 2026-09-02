import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_notifier.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

void main() {
  Future<ToastNotifier> pumpToast(WidgetTester tester) async {
    late ToastNotifier controller;

    await tester.pumpWidget(
      MaterialPreviewWidget(
        themeMode: ThemeMode.light,
        child: ToastProviderWidget(
          child: Builder(
            builder: (context) {
              controller = ToastProviderWidget.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    return controller;
  }

  testWidgets('renders title and description with the selected variant', (
    tester,
  ) async {
    final controller = await pumpToast(tester);

    controller.show(
      title: 'Falha na conexão',
      description: 'Tente novamente em instantes.',
      variant: ToastVariant.error,
      duration: Duration.zero,
    );
    await tester.pump();

    expect(find.text('Falha na conexão'), findsOneWidget);
    expect(find.text('Tente novamente em instantes.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      tester.widget<BackgroundIconWidget>(find.byType(BackgroundIconWidget)),
      isA<BackgroundIconWidget>()
          .having((widget) => widget.width, 'width', 44.0)
          .having((widget) => widget.iconSize, 'iconSize', 26.0)
          .having(
            (widget) => widget.iconColor,
            'iconColor',
            lightColors.textOnErrorSoft,
          ),
    );
    expect(
      tester.widget<Text>(find.text('Tente novamente em instantes.')).maxLines,
      2,
    );
    final contentColumn = find.ancestor(
      of: find.text('Falha na conexão'),
      matching: find.byType(Column),
    );
    expect(
      tester.getSize(find.byType(BackgroundIconWidget)).height,
      tester.getSize(contentColumn.first).height,
    );
  });

  testWidgets('dismisses before invoking an action', (tester) async {
    var actionPressed = false;
    final controller = await pumpToast(tester);

    controller.show(
      title: 'Falha na conexão',
      action: ToastAction(
        label: 'Tentar novamente',
        onPressed: () => actionPressed = true,
      ),
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(actionPressed, isTrue);
    expect(controller.toast, isNull);
  });

  testWidgets('hides a toast after its duration', (tester) async {
    final controller = await pumpToast(tester);

    controller.show(
      title: 'Mensagem temporária',
      duration: const Duration(milliseconds: 100),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.toast, isNull);
  });
}
