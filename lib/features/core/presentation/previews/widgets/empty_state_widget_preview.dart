import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/empty_state_widget.dart';

@CordatoPreview(
  group: 'Core / Estado vazio',
  name: 'Primeiro gasto / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Core / Estado vazio',
  name: 'Primeiro gasto / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewEmptyStateWidget() => const Scaffold(
  body: CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateWidget(
          icon: Icons.receipt_long_outlined,
          title: 'Seu primeiro gasto começa aqui',
          description: 'Registre uma despesa para começar.',
        ),
      ),
    ],
  ),
);

@CordatoPreview(
  group: 'Core / Estado vazio',
  name: 'Sem descrição',
  size: cordatoPhonePreviewSize,
)
Widget previewEmptyStateWithoutDescription() => const Scaffold(
  body: EmptyStateWidget(
    icon: Icons.search_off_outlined,
    title: 'Nenhum resultado encontrado',
  ),
);

@CordatoPreview(
  group: 'Core / Estado vazio',
  name: 'Texto ampliado / Paisagem',
  size: Size(640.0, 320.0),
)
Widget previewLargeTextEmptyState() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: previewEmptyStateWidget(),
  ),
);
