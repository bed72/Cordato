import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class SettingsHeaderWidget extends StatelessWidget {
  const SettingsHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) => Column(
    spacing: 6.0,
    crossAxisAlignment: .stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Configurações',
          style: context.typography.headlineMedium?.copyWith(
            color: context.colors.onSurface,
            fontWeight: .w700,
            letterSpacing: -1.0,
          ),
        ),
      ),
      Text(
        'Gerencie suas preferências.',
        style: context.typography.bodyLarge?.copyWith(
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    ],
  );
}
