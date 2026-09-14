import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/authentication/presentation/widgets/pin_field_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/button_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/resend_cooldown_label_widget.dart';

Widget _authenticationWidgetShell(Widget child) => Scaffold(
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
  name: 'Botão de envio',
  size: Size(390.0, 300.0),
  group: 'Autenticação / Widgets',
)
Widget previewMagicLinkButtonStates() => _authenticationWidgetShell(
  Column(
    spacing: 16.0,
    mainAxisSize: .min,
    crossAxisAlignment: .stretch,
    children: [
      ButtonMagicLinkWidget(isLoading: true, onPressed: () {}),
      ButtonMagicLinkWidget(isLoading: false, onPressed: () {}),
      const ButtonMagicLinkWidget(isLoading: false, onPressed: null),
    ],
  ),
);

@CordatoPreview(
  group: 'Autenticação / Widgets',
  name: 'Código PIN',
  size: Size(390.0, 220.0),
)
Widget previewPinFieldWidget() => PreviewResourceWidget<TextEditingController>(
  create: () => TextEditingController(text: '123'),
  dispose: (controller) => controller.dispose(),
  builder: (controller) => _authenticationWidgetShell(
    Form(
      child: PinFieldWidget(
        controller: controller,
        validation: const CodeValidation(),
      ),
    ),
  ),
);

@CordatoPreview(
  group: 'Autenticação / Widgets',
  name: 'Espera para reenvio',
  size: Size(390.0, 140.0),
)
Widget previewResendCooldownLabelWidget() => _authenticationWidgetShell(
  const ResendCooldownLabelWidget(remaining: Duration(seconds: 42)),
);
