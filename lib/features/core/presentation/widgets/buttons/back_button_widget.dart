import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class BackButtonWidget extends StatelessWidget {
  final VoidCallback? onPress;

  const BackButtonWidget({super.key, required this.onPress});

  @override
  Widget build(BuildContext context) => IconButtonWidget(
    width: 40.0,
    height: 40.0,
    iconSize: 24.0,
    onPress: onPress,
    icon: Icons.chevron_left,
    withoutBackground: false,
    iconColor: context.colors.onSurface,
    borderRadius: context.radius.cornerRadius050,
    backgroundColor: context.colors.onSurface.withValues(alpha: .06),
  );
}
