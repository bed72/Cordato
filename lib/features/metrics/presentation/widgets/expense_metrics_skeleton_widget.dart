import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpenseMetricsSkeletonWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando métricas de despesas',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Skeletonizer(
        child: Column(
          crossAxisAlignment: .start,
          spacing: 16.0,
          children: [
            Text('R\$ 0.000,00', style: context.typography.headlineMedium),
            Container(
              height: 36.0,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            Text(
              'Categoria   Categoria   Categoria',
              style: context.typography.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
