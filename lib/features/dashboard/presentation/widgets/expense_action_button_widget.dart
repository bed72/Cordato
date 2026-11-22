import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpenseActionButtonWidget({
  super.key,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      onTap: onTap,
      button: true,
      label: 'Adicionar gasto',
      child: ExcludeSemantics(
        child: IconButtonWidget(
          width: 48.0,
          height: 48.0,
          iconSize: 20.0,
          onPress: onTap,
          icon: Icons.receipt_long_outlined,
          iconColor: context.colors.onPrimary,
          backgroundColor: context.colors.primary,
          borderRadius: context.radius.cornerRadius100,
        ),
      ),
    );
  }
}
