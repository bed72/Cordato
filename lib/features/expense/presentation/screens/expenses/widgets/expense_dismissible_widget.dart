import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/mixins/expense_dismissible_widget_state_mixin.dart';

final class const ExpenseDismissibleWidget({
  super.key,
  required final String id,
  required final Widget child,
  required final VoidCallback onDeleted,
  required final Future<bool> Function() onConfirmDelete,
  final Future<void> Function()? onEdit,
  final bool enabled = true,
  final bool isDeleting = false,
  required final VoidCallback? onAccessibleDelete,
}) extends StatefulWidget {
  @override
  State<ExpenseDismissibleWidget> createState() =>
      _ExpenseDismissibleWidgetState();
}

final class _ExpenseDismissibleWidgetState
    extends State<ExpenseDismissibleWidget>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        ExpenseDismissibleWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Excluir despesa'): ?(canSwipe
            ? widget.onAccessibleDelete
            : null),
        const CustomSemanticsAction(label: 'Editar despesa'): ?(canSwipe
            ? widget.onEdit
            : null),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDistance = constraints.maxWidth * 0.25 < 88.0
              ? constraints.maxWidth * 0.25
              : 88.0;
          return GestureDetector(
            behavior: .opaque,
            onHorizontalDragStart: canSwipe ? startSwipe : null,
            onHorizontalDragUpdate: canSwipe
                ? (details) => updateSwipe(details, maxDistance)
                : null,
            onHorizontalDragEnd: canSwipe
                ? (details) => finishSwipe(details, maxDistance)
                : null,
            onHorizontalDragCancel: canSwipe ? cancelSwipe : null,
            child: AnimatedBuilder(
              animation: swipeController,
              child: ClipRRect(
                borderRadius: context.radius.cornerRadius300,
                child: ColoredBox(
                  color: context.colors.surfaceContainerLowest,
                  child: widget.child,
                ),
              ),
              builder: (_, child) {
                final offset = isEditingSwipe
                    ? swipeController.value.clamp(-maxDistance, 8.0)
                    : swipeController.value.clamp(-8.0, maxDistance);
                return ClipRect(
                  child: Stack(
                    children: [
                      if (isEditingSwipe && offset < 0)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: -offset,
                          child: ColoredBox(
                            color: context.colors.primaryContainer,
                            child: ExcludeSemantics(
                              child: Center(
                                child: IconWidget(
                                  icon: Icons.edit_outlined,
                                  color: context.colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!isEditingSwipe && offset > 0)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: offset,
                          child: ColoredBox(
                            color: context.colors.error,
                            child: ExcludeSemantics(
                              child: Center(
                                child: IconWidget(
                                  icon: Icons.delete_outline,
                                  color: context.colors.onError,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(-offset, 0),
                        child: child,
                      ),
                      if (widget.isDeleting)
                        Positioned(
                          left: 16.0,
                          right: 16.0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            minHeight: 2.0,
                            semanticsLabel: 'Excluindo despesa',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
