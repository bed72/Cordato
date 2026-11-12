import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/headers/collapsible_header_widget.dart';

@CordatoPreview(
  group: 'Core / Cabeçalho recolhível',
  name: 'Expandido / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Core / Cabeçalho recolhível',
  name: 'Expandido / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewExpandedCollapsibleHeader() => _headerPreview();

@CordatoPreview(
  group: 'Core / Cabeçalho recolhível',
  name: 'Recolhido',
  size: cordatoPhonePreviewSize,
)
Widget previewCollapsedHeader() => _headerPreview(initialOffset: 400.0);

@CordatoPreview(
  group: 'Core / Cabeçalho recolhível',
  name: 'Estreito / Texto ampliado',
  size: Size(320.0, 568.0),
)
Widget previewLargeTextCollapsibleHeader() => _headerPreview(textScale: 2.0);

@CordatoPreview(
  group: 'Core / Cabeçalho recolhível',
  name: 'Recolhido / Texto ampliado / Escuro',
  size: Size(320.0, 568.0),
  brightness: Brightness.dark,
)
Widget previewCollapsedLargeTextHeader() =>
    _headerPreview(initialOffset: 400.0, textScale: 2.0);

@CordatoPreview(
  group: 'Core / Cabeçalho recolhível',
  name: 'Movimento reduzido',
  size: cordatoPhonePreviewSize,
)
Widget previewReducedMotionHeader() => _headerPreview(reduceMotion: true);

Widget _headerPreview({
  double textScale = 1.0,
  bool reduceMotion = false,
  double initialOffset = 0.0,
}) => PreviewResourceWidget<ScrollController>(
  dispose: (controller) => controller.dispose(),
  create: () => ScrollController(initialScrollOffset: initialOffset),
  builder: (controller) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        reduceMotion: reduceMotion,
      ),
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            controller: controller,
            slivers: [
              CollapsibleHeaderWidget(
                title: 'Novo gasto',
                description: 'Preencha as informações abaixo para cadastrar um novo gasto.',
                leading: BackButtonWidget(onPress: () {}),
              ),
              SliverList.list(
                children: [
                  for (var index = 0; index < 24; index++)
                    Padding(
                      padding: const .all(16.0),
                      child: Text('Conteúdo de exemplo ${index + 1}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
