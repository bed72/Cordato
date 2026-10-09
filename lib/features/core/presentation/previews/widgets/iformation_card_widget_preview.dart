import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/cards/iformation_card_widget.dart';

@CordatoPreview(
  group: 'Core / Cards',
  name: 'Informativo / Claro',
  size: Size(390.0, 240.0),
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Core / Cards',
  name: 'Informativo / Escuro',
  size: Size(390.0, 240.0),
  brightness: Brightness.dark,
)
Widget previewIformationCardWidget() => Scaffold(
  body: Center(
    child: Padding(
      padding: const .all(16.0),
      child: Builder(
        builder: (context) => IformationCardWidget(
          title: 'Mais valor registrado',
          description: 'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
          icon: Icons.trending_up,
          iconColor: context.colors.primary,
          iconBackgroundColor: context.colors.primary.withValues(alpha: 0.12),
        ),
      ),
    ),
  ),
);
