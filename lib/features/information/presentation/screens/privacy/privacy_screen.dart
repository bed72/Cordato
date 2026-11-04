import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/information/presentation/content/information_content.dart';
import 'package:cordato/features/information/presentation/widgets/information_document_widget.dart';

final class const PrivacyScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const InformationDocumentWidget(
      title: 'Política de Privacidade',
      description: 'Entenda como cuidamos dos seus dados.',
      summary: InformationContent.privacySummary,
      sections: InformationContent.privacySections,
    );
  }
}
