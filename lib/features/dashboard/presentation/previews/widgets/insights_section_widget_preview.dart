import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';

import 'package:cordato/features/dashboard/presentation/widgets/insights/insights_section_widget.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

@CordatoPreview(
  group: 'Dashboard / Insights',
  name: 'Carregando',
  size: Size(390.0, 260.0),
)
Widget previewLoadingInsightsSectionWidget() => _sectionPreview();

@CordatoPreview(
  group: 'Dashboard / Insights',
  name: 'Sem insights',
  size: Size(390.0, 160.0),
)
Widget previewEmptyInsightsSectionWidget() =>
    _sectionPreview(type: const Right([]));

@CordatoPreview(
  group: 'Dashboard / Insights',
  name: 'Cards / Claro',
  size: Size(390.0, 280.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Dashboard / Insights',
  name: 'Cards / Escuro',
  size: Size(390.0, 280.0),
  brightness: Brightness.dark,
)
Widget previewInsightsSectionWidget() =>
    _sectionPreview(type: Right(_insights()));

@CordatoPreview(
  group: 'Dashboard / Insights',
  name: 'Texto ampliado',
  size: Size(390.0, 440.0),
)
Widget previewLargeTextInsightsSectionWidget() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.6)),
    child: _sectionPreview(type: Right(_insights())),
  ),
);

Widget _sectionPreview({GetRepositoryType? type}) => Scaffold(
  body: SingleChildScrollView(
    padding: const .symmetric(vertical: 24.0),
    child: InsightsSectionWidget(insights: type?.right),
  ),
);

List<InsightEntity> _insights() => [
  for (final (index, fixture) in [
    (
      title: 'Mais valor registrado',
      type: 'registered_amount_increase',
      description: 'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
    ),
    (
      title: 'Uma liderança recorrente',
      type: 'category_lead_streak',
      description: 'Moradia segue líder nos registros deste mês, após liderar os dois meses anteriores.',
    ),
    (
      title: 'Uma nova análise',
      type: 'future_type',
      description:
          'Tipos novos continuam visíveis com um ícone e uma cor neutros.',
    ),
  ].indexed)
    InsightEntity(
      id: 'preview-insight-$index',
      type: fixture.type,
      group: 'comparison',
      title: fixture.title,
      description: fixture.description,
      period: InsightPeriodEntity(
        to: DateTime(2026, 10, 9),
        from: DateTime(2026, index == 1 ? 8 : 10, 1),
      ),
    ),
];
