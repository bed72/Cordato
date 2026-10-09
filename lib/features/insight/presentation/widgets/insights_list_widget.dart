import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/presentation/widgets/insight_card_widget.dart';

final class const InsightsListWidget({
  super.key,
  required final List<InsightEntity> insights,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: .horizontal,
      primary: false,
      padding: const .symmetric(horizontal: 20.0),
      child: IntrinsicHeight(
        child: Row(
          spacing: 12.0,
          crossAxisAlignment: .stretch,
          children: [
            for (final insight in insights)
              SizedBox(
                key: ValueKey(insight.id),
                width: constraints.maxWidth - 40.0,
                child: InsightCardWidget(insight: insight),
              ),
          ],
        ),
      ),
    ),
  );
}
