import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_section_widget.dart';
import 'package:cordato/features/information/presentation/content/information_content.dart';

final class const InformationContactWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MenuSectionWidget(
    label: 'Fale com a gente',
    child: MenuCardWidget(
      children: [
        Padding(
          padding: const .symmetric(vertical: 16.0),
          child: Column(
            spacing: 8.0,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                InformationContent.responsible,
                style: context.typography.titleSmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                InformationContent.email,
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.primary,
                ),
              ),
              Text(
                'Selecione o e-mail para copiar. Envie sua dúvida ou '
                'solicitação de privacidade sem incluir senhas, links '
                'de recuperação ou informações financeiras desnecessárias.',
                style: context.typography.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
