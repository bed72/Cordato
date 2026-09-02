import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

final class MagicLinkSubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const MagicLinkSubmitButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButtonWidget(
    onTap: onPressed,
    label: 'Enviar link',
    isLoading: isLoading,
  );
}
