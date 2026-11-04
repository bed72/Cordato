import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/information/presentation/content/information_content.dart';
import 'package:cordato/features/information/presentation/widgets/help_section_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_contact_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_page_widget.dart';

final class const HelpScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InformationPageWidget(
      title: 'Ajuda',
      description:
          'Respostas simples para cuidar da sua conta e das suas despesas.',
      children: [
        for (final section in InformationContent.helpSections)
          HelpSectionWidget(title: section.title, questions: section.questions),
        const InformationContactWidget(),
      ],
    );
  }
}
