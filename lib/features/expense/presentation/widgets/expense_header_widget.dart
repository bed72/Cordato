import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpenseHeaderWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    spacing: 6.0,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Novo gasto',
          style: context.typography.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            color: context.colors.onSurface,
          ),
        ),
      ),
      Text(
        'Preencha as informações abaixo para cadastrar um novo gasto.',
        style: context.typography.bodyLarge?.copyWith(
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    ],
  );
}
