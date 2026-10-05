import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const SettingsCardWidget({
  super.key,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: .antiAlias,
    decoration: BoxDecoration(
      borderRadius: context.radius.cornerRadius100,
      border: Border.all(color: context.colors.outlineVariant),
    ),
    child: Column(children: _withDividers(context)),
  );

  List<Widget> _withDividers(BuildContext context) {
    final widgets = <Widget>[];

    for (var index = 0; index < children.length; index++) {
      widgets.add(
        Padding(
          padding: const .symmetric(horizontal: 16.0),
          child: children[index],
        ),
      );

      if (index < children.length - 1) {
        widgets.add(Divider(height: 1.0, color: context.colors.outlineVariant));
      }
    }

    return widgets;
  }
}
