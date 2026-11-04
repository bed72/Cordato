import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

final class const ExpenseCategoryItemWidget({
  super.key,
  required final bool selected,
  required final VoidCallback onPressed,
  required final ExpenseCategoryEnum category,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = category.color(context);
    return Container(
      padding: const .symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: context.radius.cornerRadius300,
        border: .all(
          color: selected ? color.withValues(alpha: 0.6) : Colors.transparent,
        ),
        color: selected
            ? Color.alphaBlend(
                color.withValues(alpha: context.isDark ? 0.10 : 0.05),
                context.colors.surface,
              )
            : null,
      ),
      child: MenuItemWidget(
        label: category.label,
        selected: selected,
        showChevron: false,
        onPressed: onPressed,
        description: category.description,
        leading: BackgroundIconWidget(
          width: 40.0,
          height: 40.0,
          iconSize: 22.0,
          iconColor: color,
          icon: category.icon,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
