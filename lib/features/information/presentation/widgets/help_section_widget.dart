import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_section_widget.dart';

final class const HelpSectionWidget({
  super.key,
  required final String title,
  required final List<({String question, String answer})> questions,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MenuSectionWidget(
      label: title,
      child: MenuCardWidget(
        itemPadding: .zero,
        children: [
          for (final item in questions)
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: context.colors.onSurfaceVariant,
              collapsedIconColor: context.colors.onSurfaceVariant,
              childrenPadding: const .fromLTRB(16.0, 0.0, 16.0, 16.0),
              tilePadding: const .symmetric(horizontal: 16.0, vertical: 4.0),
              title: Text(
                item.question,
                style: context.typography.bodyMedium?.copyWith(
                  fontWeight: .w500,
                  color: context.colors.onSurface,
                ),
              ),
              children: [
                Align(
                  alignment: .centerLeft,
                  child: Text(
                    item.answer,
                    style: context.typography.bodyMedium?.copyWith(
                      height: 1.6,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
