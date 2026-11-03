import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/icons/mixins/icon_widget_state_mixin.dart';

final class const IconWidget({
  super.key,
  required final LucideAnimatedIconData icon,
  final double? size,
  final Color? color,
  final String? semanticsLabel,
}) extends StatefulWidget {
  @override
  State<IconWidget> createState() => _IconWidgetState();
}

final class _IconWidgetState extends State<IconWidget>
    with IconWidgetStateMixin {
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticsLabel,
    child: IgnorePointer(
      child: LucideAnimatedIcon(
        icon: widget.icon,
        duration: duration,
        size: widget.size ?? IconTheme.of(context).size ?? 24.0,
        color:
            widget.color ??
            IconTheme.of(context).color ??
            context.colors.onSurface,
        trigger: AnimationTrigger.manual,
        controller: controller,
      ),
    ),
  );
}
