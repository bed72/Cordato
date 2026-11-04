import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/information/presentation/content/information_content.dart';
import 'package:cordato/features/information/presentation/widgets/information_page_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_contact_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_section_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_summary_widget.dart';

final class const InformationDocumentWidget({
  super.key,
  required final String title,
  required final String summary,
  required final String description,
  required final List<({String title, List<String> paragraphs})> sections,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InformationPageWidget(
      title: title,
      description: description,
      children: [
        Text(
          'Versão ${InformationContent.version} · '
          'Atualizado em ${InformationContent.updatedAt}',
          style: context.typography.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        InformationSummaryWidget(summary: summary),
        for (var index = 0; index < sections.length; index++)
          InformationSectionWidget(
            title: '${index + 1}. ${sections[index].title}',
            paragraphs: sections[index].paragraphs,
          ),
        const InformationContactWidget(),
      ],
    );
  }
}
