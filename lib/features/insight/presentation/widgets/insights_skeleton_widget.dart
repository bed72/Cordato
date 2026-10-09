import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/presentation/widgets/insights_list_widget.dart';

final class const InsightsSkeletonWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Carregando insights',
    child: ExcludeSemantics(
      child: Skeletonizer(
        child: InsightsListWidget(
          insights: List.generate(
            2,
            (index) => InsightEntity(
              id: 'loading-$index',
              title: 'Carregando análise',
              type: '',
              group: '',
              description:
                  'Carregando informações sobre os seus registros financeiros.',
              period: InsightPeriodEntity(
                from: DateTime(2026),
                to: DateTime(2026),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
