import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/cards/iformation_card_widget.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/presentation/mixins/insight_card_widget_mixin.dart';

final class const InsightCardWidget({
  super.key,
  required final InsightEntity insight,
}) extends StatelessWidget with InsightCardWidgetMixin {
  @override
  Widget build(BuildContext context) {
    final visual = appearance(context, insight.type);

    return IformationCardWidget(
      title: insight.title,
      description: insight.description,
      icon: visual.icon,
      iconColor: visual.color,
      iconBackgroundColor: visual.color.withValues(alpha: 0.12),
    );
  }
}
