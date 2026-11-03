import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_animation_scope_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';

mixin IconWidgetStateMixin on State<IconWidget> {
  final LucideAnimatedIconController controller =
      LucideAnimatedIconController();
  int? _lastAnimation;
  bool _enabled = true;

  bool get canAnimate =>
      _enabled &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
      TickerMode.valuesOf(context).enabled;

  Duration get duration {
    if (widget.icon.animation case final animation?) return animation.duration;
    for (final element in widget.icon.elements) {
      if (element.animation case final animation?) return animation.duration;
    }
    return const Duration(milliseconds: 400);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = IconAnimationScopeWidget.maybeOf(context);
    _enabled = scope?.enabled ?? true;
    final animation = scope?.notifier?.value ?? 0;
    if (_lastAnimation != animation) {
      _lastAnimation = animation;
      scheduleAnimation();
    }
    if (!canAnimate) controller.reset();
  }

  @override
  void didUpdateWidget(IconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon != widget.icon) scheduleAnimation();
  }

  void scheduleAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && canAnimate) controller.animate();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
