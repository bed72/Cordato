import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const MenuItemWidget({
  super.key,
  required final String label,
  final String? value,
  final IconData? icon,
  final Widget? leading,
  final Widget? trailing,
  final VoidCallback? onPressed,
  final double height = 56.0,
  final double spacing = 16.0,
  final bool showChevron = true,
  final double disabledOpacity = 1.0,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: onPressed == null ? disabledOpacity : 1.0,
      child: _buildContent(context),
    );

    return Semantics(
      label: label,
      value: value,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: onPressed == null
            ? content
            : BounceWidget.withOnPress(onPress: onPressed, child: content),
      ),
    );
  }

  SizedBox _buildContent(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        spacing: spacing,
        children: [
          ?_buildLeading(context),
          _buildLabel(context),
          ?_buildValue(context),
          ?trailing,
          ?_buildChevron(context),
        ],
      ),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;
    if (icon == null) return null;

    return Icon(icon, size: 24.0, color: context.colors.onSurfaceVariant);
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

    return value == null ? Expanded(child: text) : text;
  }

  Expanded? _buildValue(BuildContext context) {
    if (value == null) return null;

    return Expanded(
      child: Text(
        value!,
        maxLines: 1,
        overflow: .ellipsis,
        textAlign: .end,
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
      icon: Icons.chevron_right,
      color: context.colors.onSurfaceVariant,
    );
  }
}
