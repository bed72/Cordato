import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_interaction_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const MenuItemWidget({
  super.key,
  required final String label,
  final bool? selected,
  final String? value,
  final Widget? leading,
  final Widget? trailing,
  final String? description,
  final VoidCallback? onPressed,
  final double height = 56.0,
  final double spacing = 16.0,
  final bool showChevron = true,
  final double disabledOpacity = 1.0,
  final LucideAnimatedIconData? icon,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: onPressed == null ? disabledOpacity : 1.0,
      child: _buildContent(context),
    );

    return Semantics(
      label: description == null ? label : '$label, $description',
      value: value,
      selected: selected,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: IconInteractionWidget(
          enabled: onPressed != null,
          child: onPressed == null
              ? content
              : BounceWidget.withOnPress(onPress: onPressed, child: content),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final content = Row(
      spacing: spacing,
      children: [
        ?_buildLeading(context),
        _buildLabel(context),
        ?_buildValue(context),
        ?trailing,
        ?_buildChevron(context),
      ],
    );
    return description == null
        ? SizedBox(height: height, child: content)
        : ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: content,
          );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;
    if (icon == null) return null;

    return IconWidget(
      icon: icon!,
      size: 24.0,
      color: context.colors.onSurfaceVariant,
    );
  }

  Widget _buildLabel(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: .ellipsis,
      style: context.typography.bodyMedium?.copyWith(
        color: context.colors.onSurface,
      ),
    );

    final content = description == null
        ? text
        : Column(
            spacing: 4.0,
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              text,
              Text(
                description!,
                maxLines: 1,
                overflow: .ellipsis,
                style: context.typography.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          );
    return value == null ? Expanded(child: content) : content;
  }

  Expanded? _buildValue(BuildContext context) {
    if (value == null) return null;

    return Expanded(
      child: Text(
        value!,
        maxLines: 1,
        textAlign: .end,
        overflow: .ellipsis,
        style: context.typography.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }

  IconWidget? _buildChevron(BuildContext context) {
    if (!showChevron) return null;

    return IconWidget(
      size: 24.0,
      icon: chevron_right,
      color: context.colors.onSurfaceVariant,
    );
  }
}
