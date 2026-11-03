import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_animation_scope_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/mixins/icon_interaction_widget_state_mixin.dart';

final class const IconInteractionWidget({
  super.key,
  required final Widget child,
  final bool enabled = true,
}) extends StatefulWidget {
  @override
  State<IconInteractionWidget> createState() => _IconInteractionWidgetState();
}

final class _IconInteractionWidgetState extends State<IconInteractionWidget>
    with IconInteractionWidgetStateMixin {
  @override
  Widget build(BuildContext context) => IconAnimationScopeWidget(
    notifier: animation,
    enabled: widget.enabled,
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: onKeyEvent,
      child: MouseRegion(
        onEnter: (_) => animate(),
        child: Listener(
          behavior: .translucent,
          onPointerDown: (_) => animate(),
          child: widget.child,
        ),
      ),
    ),
  );
}
