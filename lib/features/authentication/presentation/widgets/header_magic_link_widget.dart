import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class HeaderMagicLinkWidget extends StatelessWidget {
  const HeaderMagicLinkWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6.0,
      crossAxisAlignment: .stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Que bom ter você por aqui',
            style: context.typography.headlineMedium?.copyWith(
              fontWeight: .w700,
              letterSpacing: -1.0,
              color: context.colors.onSurface,
            ),
          ),
        ),
        Text(
          'Entre com seu e-mail e enviaremos o link',
          style: context.typography.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant.withValues(alpha: .8),
          ),
        ),
      ],
    );
  }
}
