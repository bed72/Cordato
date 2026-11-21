import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/information/presentation/content/information_content.dart';
import 'package:cordato/features/information/presentation/widgets/help_section_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_page_widget.dart';
import 'package:cordato/features/information/presentation/widgets/information_contact_widget.dart';

final class const HelpScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InformationPageWidget(
      title: 'Ajuda',
      description:
          'Respostas simples para cuidar do seu perfil e das despesas locais.',
      children: [
        for (final section in InformationContent.helpSections)
          HelpSectionWidget(title: section.title, questions: section.questions),
        const InformationContactWidget(),
      ],
    );
  }
}
