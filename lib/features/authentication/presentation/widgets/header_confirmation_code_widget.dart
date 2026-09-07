import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class HeaderConfirmationCodeWidget extends StatelessWidget {
  const HeaderConfirmationCodeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6.0,
      crossAxisAlignment: .stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Confirme seu código',
            style: context.typography.headlineMedium?.copyWith(
              fontWeight: .w700,
              letterSpacing: -1.0,
              color: context.colors.onSurface,
            ),
          ),
        ),
        Text(
          'Enviamos um código de 6 dígitos para o seu e-mail',
          style: context.typography.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant.withValues(alpha: .8),
          ),
        ),
      ],
    );
  }
}
