import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

final class const ButtonSignUpWidget({
  super.key,
  required final bool isLoading,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ElevatedButtonWidget(
    label: 'Criar conta',
    onTap: onPressed,
    isLoading: isLoading,
  );
}
