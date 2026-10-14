import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_dismissible_widget.dart';

mixin ExpenseDismissibleWidgetStateMixin
    on
        State<ExpenseDismissibleWidget>,
        TickerProvider,
        AutomaticKeepAliveClientMixin<ExpenseDismissibleWidget> {
  late final swipeController = AnimationController.unbounded(vsync: this);
  bool _isHandlingSwipe = false;
  bool _returningFromEdit = false;

  bool get isEditingSwipe =>
      _isHandlingSwipe ? _returningFromEdit : swipeController.value < 0;

  bool get canSwipe =>
      widget.enabled && !widget.isDeleting && !_isHandlingSwipe;

  @override
  bool get wantKeepAlive => _isHandlingSwipe;

  @override
  void dispose() {
    swipeController.dispose();
    super.dispose();
  }

  void startSwipe(DragStartDetails _) => swipeController.stop();

  void updateSwipe(DragUpdateDetails details, double maxDistance) {
    swipeController.value = (swipeController.value - details.delta.dx).clamp(
      widget.onEdit == null ? 0.0 : -maxDistance,
      maxDistance,
    );
  }

  Future<void> finishSwipe(DragEndDetails details, double maxDistance) =>
      _returnToRest(
        activate: swipeController.value.abs() >= maxDistance * 0.65,
        velocity: -details.velocity.pixelsPerSecond.dx,
      );

  Future<void> cancelSwipe() => _returnToRest(activate: false);

  Future<void> _returnToRest({
    required bool activate,
    double velocity = 0,
  }) async {
    if (_isHandlingSwipe) return;

    final id = widget.id;
    final editing = swipeController.value < 0;
    setState(() {
      _isHandlingSwipe = true;
      _returningFromEdit = editing;
    });
    updateKeepAlive();

    try {
      final returning = swipeController
          .animateWith(
            SpringSimulation(
              const SpringDescription(
                mass: 0.5,
                damping: 14.0,
                stiffness: 280.0,
              ),
              swipeController.value,
              0.0,
              velocity,
            ),
          )
          .orCancel;
      final action = activate && widget.enabled && !editing
          ? widget.onConfirmDelete()
          : Future<bool>.value(false);

      await returning;
      if (!mounted || widget.id != id) return;
      swipeController.value = 0.0;

      if (editing && activate && widget.enabled) {
        await widget.onEdit?.call();
        return;
      }

      final deleted = await action;
      if (mounted && widget.id == id && deleted) widget.onDeleted();
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) {
        setState(() => _isHandlingSwipe = false);
        updateKeepAlive();
      }
    }
  }
}
