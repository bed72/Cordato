import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/information/presentation/content/information_content.dart';
import 'package:cordato/features/information/presentation/widgets/information_document_widget.dart';

final class const TermsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const InformationDocumentWidget(
      title: 'Termos de uso',
      description: 'O que você precisa saber para usar o Cordato.',
      summary: InformationContent.termsSummary,
      sections: InformationContent.termsSections,
    );
  }
}
