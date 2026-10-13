import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

const _title = 'Não foi possível carregar sua Dashboard.';
const _description =
    'Não conseguimos carregar suas informações agora. Tente novamente.';

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Claro / sem cabeçalho / ação principal',
  brightness: Brightness.light,
  size: cordatoPhonePreviewSize,
)
Widget previewErrorScreenLight() => ErrorScreen(
  title: _title,
  description: _description,
  actionLabel: 'Tentar novamente',
  onAction: () {},
);

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Escuro / cabeçalho / duas ações',
  brightness: Brightness.dark,
  size: cordatoPhonePreviewSize,
)
Widget previewErrorScreenDark() => ErrorScreen(
  appBar: AppBar(
    leading: BackButtonWidget(onPress: () {}),
    title: const Text('Dados pessoais'),
  ),
  onAction: () {},
  onSecondaryAction: () {},
  description: _description,
  image: AssetEnum.connectionError,
  secondaryActionLabel: 'Voltar',
  actionLabel: 'Tentar novamente',
  title: 'Não foi possível carregar seus dados.',
);

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Claro / cabeçalho / duas ações',
  brightness: Brightness.light,
  size: cordatoPhonePreviewSize,
)
Widget previewErrorScreenWithHeader() => ErrorScreen(
  appBar: AppBar(
    title: const Text('Cordato'),
    automaticallyImplyLeading: false,
  ),
  title: _title,
  onAction: () {},
  onSecondaryAction: () {},
  description: _description,
  actionLabel: 'Tentar novamente',
  secondaryActionLabel: 'Agora não',
);

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Loading / cabeçalho / duas ações',
  brightness: Brightness.light,
  size: cordatoPhonePreviewSize,
)
Widget previewErrorScreenLoading() => ErrorScreen(
  appBar: AppBar(
    title: const Text('Cordato'),
    automaticallyImplyLeading: false,
  ),
  title: _title,
  isLoading: true,
  onAction: () {},
  onSecondaryAction: () {},
  description: _description,
  actionLabel: 'Tentar novamente',
  secondaryActionLabel: 'Agora não',
);

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Escuro / loading / sem cabeçalho',
  brightness: Brightness.dark,
  size: cordatoPhonePreviewSize,
)
Widget previewErrorScreenDarkLoading() => ErrorScreen(
  title: _title,
  onAction: () {},
  isLoading: true,
  description: _description,
  actionLabel: 'Tentar novamente',
);

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Ações desabilitadas',
  brightness: Brightness.light,
  size: cordatoPhonePreviewSize,
)
Widget previewErrorScreenDisabled() => const ErrorScreen(
  title: _title,
  onAction: null,
  description: _description,
  secondaryActionLabel: 'Voltar',
  actionLabel: 'Tentar novamente',
);

@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Tela pequena / texto 200% / ações longas',
  brightness: Brightness.light,
  size: Size(320.0, 480.0),
)
@CordatoPreview(
  group: 'Core / ErrorScreen',
  name: 'Escuro / paisagem / texto 200%',
  brightness: Brightness.dark,
  size: Size(568.0, 320.0),
)
Widget previewErrorScreenLargeText() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: ErrorScreen(
      appBar: AppBar(
        title: const Text('Cordato'),
        leading: BackButtonWidget(onPress: () {}),
      ),
      title: _title,
      onAction: () {},
      onSecondaryAction: () {},
      description: _description,
      secondaryActionLabel: 'Voltar para a tela anterior',
      actionLabel: 'Tentar carregar as informações novamente',
    ),
  ),
);
