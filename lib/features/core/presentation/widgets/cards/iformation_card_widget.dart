import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/cards/iformation_card_content_widget.dart';

final class const IformationCardWidget({
  super.key,
  required final String title,
  required final LucideAnimatedIconData icon,
  required final Color iconColor,
  required final String description,
  required final Color iconBackgroundColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Card(
        margin: .zero,
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: context.radius.cornerRadius100,
        ),
        child: Padding(
          padding: const .all(12.0),
          child: IformationCardContentWidget(
            icon: icon,
            title: title,
            iconColor: iconColor,
            description: description,
            iconBackgroundColor: iconBackgroundColor,
          ),
        ),
      ),
    );
  }
}
