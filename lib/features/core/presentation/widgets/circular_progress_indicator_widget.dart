import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

class const CircularProgressIndicatorWidget({
  super.key,
  final Color? color,
  final double? width,
  final double? height,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: width ?? 20.0,
      height: height ?? 20.0,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        valueColor: AlwaysStoppedAnimation(color ?? context.colors.onPrimary),
      ),
    ),
  );
}
