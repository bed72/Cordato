import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpenseActionButtonWidget({
  super.key,
  required final VoidCallback onTap,
  required final VoidCallback onLongPress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BounceWidget.withoutOnPress(
      child: Semantics(
        onTap: onTap,
        button: true,
        onLongPress: onLongPress,
        label: 'Adicionar gasto',
        hint: 'Toque para cadastrar ou mantenha pressionado para capturar fala. O reconhecedor pode usar rede.',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              height: 48,
              child: IconWidget(
                size: 20,
                icon: Icons.receipt_long_outlined,
                color: context.colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
