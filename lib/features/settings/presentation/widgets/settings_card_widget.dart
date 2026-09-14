import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class SettingsCardWidget extends StatelessWidget {
  final List<Widget> children;

  const SettingsCardWidget({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: .antiAlias,
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.outlineVariant),
      borderRadius: context.radius.cornerRadius100,
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
