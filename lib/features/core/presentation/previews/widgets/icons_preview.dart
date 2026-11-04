import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';

@CordatoPreview(
  group: 'Core / Ícones',
  name: 'Ícones Material estáticos',
  size: Size(390.0, 360.0),
)
Widget previewIcons() => Scaffold(
  body: Padding(
    padding: const .all(24.0),
    child: Builder(
      builder: (context) => Column(
        crossAxisAlignment: .stretch,
        spacing: 16.0,
        children: [
          const Text('Ícones padrão nos controles compartilhados.'),
          Row(
            spacing: 16.0,
            children: [
              BackButtonWidget(onPress: () {}),
              IconButtonWidget(
                icon: Icons.refresh,
                onPress: () {},
                iconColor: context.colors.onPrimary,
                backgroundColor: context.colors.primary,
              ),
              const BackButtonWidget(onPress: null),
            ],
          ),
          MenuItemWidget(
            label: 'Dados pessoais',
            icon: Icons.person_outline,
            onPressed: () {},
          ),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: MenuItemWidget(
              label: 'Movimento reduzido',
              icon: Icons.auto_awesome_outlined,
              onPressed: () {},
            ),
          ),
        ],
      ),
    ),
  ),
);
