import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const MenuCardWidget({
  super.key,
  required final List<Widget> children,
  final Color? backgroundColor,
  final bool showDividers = true,
  final EdgeInsetsGeometry itemPadding = const .symmetric(horizontal: 16.0),
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.radius.cornerRadius100,
        border: .all(color: context.colors.outlineVariant),
      ),
      child: Column(children: _buildDivider(context)),
    );
  }

  List<Widget> _buildDivider(BuildContext context) {
    final widgets = <Widget>[];

    for (int index = 0; index < children.length; index++) {
      widgets.add(Padding(padding: itemPadding, child: children[index]));

      if (showDividers && index < children.length - 1) {
        widgets.add(Divider(height: 1.0, color: context.colors.outlineVariant));
      }
    }

    return widgets;
  }
}
