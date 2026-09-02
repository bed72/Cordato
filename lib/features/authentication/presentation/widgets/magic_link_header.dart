import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class MagicLinkHeader extends StatelessWidget {
  const MagicLinkHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Entrar por link mágico', style: context.typography.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Informe seu email para receber um link de acesso.',
          style: context.typography.bodyLarge,
        ),
      ],
    );
  }
}
