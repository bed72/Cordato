import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const IconWidget({
  super.key,
  required final IconData icon,
  final double? size,
  final Color? color,
  final String? semanticsLabel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: IgnorePointer(
      child: Icon(
        icon,
        size: size ?? IconTheme.of(context).size ?? 24.0,
        color: color ?? IconTheme.of(context).color ?? context.colors.onSurface,
      ),
    ),
  );
}
