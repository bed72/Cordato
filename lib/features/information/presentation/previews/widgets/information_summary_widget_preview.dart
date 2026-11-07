import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/information/presentation/content/information_content.dart';
import 'package:cordato/features/core/presentation/widgets/cards/summary_card_widget.dart';

@CordatoPreview(
  group: 'Informações / Widgets',
  name: 'Resumo dos termos / Claro',
  size: Size(390.0, 360.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Informações / Widgets',
  name: 'Resumo dos termos / Escuro',
  size: Size(390.0, 360.0),
  brightness: Brightness.dark,
)
Widget previewTermsSummaryWidget() => _summary(InformationContent.termsSummary);

@CordatoPreview(
  group: 'Informações / Widgets',
  name: 'Resumo da privacidade / Claro',
  size: Size(390.0, 400.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Informações / Widgets',
  name: 'Resumo da privacidade / Escuro',
  size: Size(390.0, 400.0),
  brightness: Brightness.dark,
)
Widget previewPrivacySummaryWidget() =>
    _summary(InformationContent.privacySummary);

@CordatoPreview(
  group: 'Informações / Widgets',
  name: 'Resumo da privacidade / Estreito e ampliado',
  size: Size(320.0, 568.0),
)
Widget previewPrivacySummaryLargeTextWidget() =>
    _summary(InformationContent.privacySummary, textScale: 2.0);

Widget _summary(String summary, {double textScale = 1.0}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: SafeArea(
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const .all(16.0),
            child: SummaryCardWidget(summary: summary),
          ),
        ),
      ),
    ),
  ),
);
