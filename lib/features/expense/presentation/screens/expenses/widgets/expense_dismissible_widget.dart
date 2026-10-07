import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpenseDismissibleWidget({
  super.key,
  required final String id,
  required final Widget child,
  required final VoidCallback onDeleted,
  required final Future<bool> Function() onConfirmDelete,
  final bool enabled = true,
  final bool isDeleting = false,
  required final VoidCallback? onAccessibleDelete,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Excluir despesa'):
            ?onAccessibleDelete,
      },
      child: Dismissible(
        key: ValueKey(id),
        onDismissed: (_) => onDeleted(),
        confirmDismiss: (_) => onConfirmDelete(),
        direction: enabled ? .endToStart : .none,
        dismissThresholds: const {.endToStart: 0.3},
        background: ColoredBox(
          color: context.colors.error,
          child: ExcludeSemantics(
            child: Align(
              alignment: .centerRight,
              child: Padding(
                padding: const .symmetric(horizontal: 28.0),
                child: isDeleting
                    ? SizedBox.square(
                        dimension: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: context.colors.onError,
                        ),
                      )
                    : IconWidget(
                        icon: Icons.delete_outline,
                        color: context.colors.onError,
                      ),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: context.radius.cornerRadius300,
          child: ColoredBox(
            color: context.colors.surfaceContainerLowest,
            child: child,
          ),
        ),
      ),
    );
  }
}
