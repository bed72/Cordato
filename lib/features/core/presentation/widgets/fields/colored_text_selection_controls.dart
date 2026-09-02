import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

final class ColoredTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  final TextSelectionControls delegate;
  final Color color;

  ColoredTextSelectionControls({required this.delegate, required this.color});

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) => TextSelectionTheme(
    data: TextSelectionTheme.of(context).copyWith(selectionHandleColor: color),
    child: CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(selectionHandleColor: color),
      child: Builder(
        builder: (BuildContext context) =>
            delegate.buildHandle(context, type, textLineHeight, onTap),
      ),
    ),
  );

  @override
  Size getHandleSize(double textLineHeight) =>
      delegate.getHandleSize(textLineHeight);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      delegate.getHandleAnchor(type, textLineHeight);
}
