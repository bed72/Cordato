import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_interaction_widget.dart';
import 'package:cordato/features/core/presentation/widgets/cards/iformation_card_content_widget.dart';

final class const SettingsInvitePartnerWidget({
  super.key,
  required final VoidCallback? onInvitePartnerPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = Card(
      margin: .zero,
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.radius.cornerRadius100,
      ),
      child: Padding(
        padding: const .all(12.0),
        child: Row(
          spacing: 12.0,
          children: [
            Expanded(
              child: IformationCardContentWidget(
                title: 'Convidar parceiro',
                icon: lucide.user_round_plus,
                description: 'Comecem a usar juntos',
                iconColor: context.colors.onPrimaryContainer,
                iconBackgroundColor: context.colors.primaryContainer,
              ),
            ),
            IconWidget(
              icon: lucide.chevron_right,
              size: 24.0,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: onInvitePartnerPressed != null,
      label: 'Convidar parceiro',
      child: ExcludeSemantics(
        child: IconInteractionWidget(
          enabled: onInvitePartnerPressed != null,
          child: onInvitePartnerPressed == null
              ? content
              : BounceWidget.withOnPress(
                  onPress: onInvitePartnerPressed,
                  child: content,
                ),
        ),
      ),
    );
  }
}
