import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/hold_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

Widget _buttonShell(Widget child) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  ),
);

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Elevado',
  size: Size(390.0, 160.0),
)
Widget previewElevatedButtonWidget() =>
    _buttonShell(ElevatedButtonWidget(label: 'Continuar', onTap: () {}));

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Contornado',
  size: Size(390.0, 160.0),
)
Widget previewOutlineButtonWidget() =>
    _buttonShell(OutlineButtonWidget(label: 'Agora não', onTap: () {}));

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Perigo',
  size: Size(390.0, 160.0),
)
Widget previewDangerButtonWidget() =>
    _buttonShell(DangerButtonWidget(label: 'Excluir conta', onTap: () {}));

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Texto e link',
  size: Size(390.0, 180.0),
)
Widget previewTextAndLinkButtonWidgets() => _buttonShell(
  Column(
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    spacing: 20.0,
    children: [
      TextButtonWidget(label: 'Saiba mais', onTap: () {}),
      LinkButtonWidget(label: 'Política de privacidade', onTap: () {}),
    ],
  ),
);

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Ícone e voltar',
  size: Size(390.0, 160.0),
)
Widget previewIconAndBackButtonWidgets() => _buttonShell(
  Builder(
    builder: (context) => Row(
      mainAxisAlignment: .center,
      spacing: 20.0,
      children: [
        IconButtonWidget(
          icon: settings,
          onPress: () {},
          iconColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        BackButtonWidget(onPress: () {}),
      ],
    ),
  ),
);

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Segurar',
  size: Size(390.0, 160.0),
)
Widget previewHoldButtonWidget() => _buttonShell(
  HoldButtonWidget(
    label: 'Segure para confirmar',
    onTap: () {},
    onHoldComplete: () {},
  ),
);

@CordatoPreview(
  group: 'Core / Botões',
  name: 'Bounce',
  size: Size(390.0, 160.0),
)
Widget previewBounceWidget() => _buttonShell(
  Center(
    child: BounceWidget.withOnPress(
      onPress: () {},
      child: const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Text('Pressione'),
        ),
      ),
    ),
  ),
);
