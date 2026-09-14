import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_scaffold_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/logout_bottom_sheet_widget.dart';

@CordatoPreview(
  group: 'Configurações / Widgets',
  name: 'Confirmação de saída',
  size: Size(390.0, 360.0),
)
Widget previewLogoutBottomSheetWidget() => const Scaffold(
  body: Align(
    alignment: .bottomCenter,
    child: BottomSheetScaffoldWidget(
      title: 'Deseja sair?',
      subtitle: 'Você precisará entrar novamente para acessar sua conta.',
      child: LogoutBottomSheetWidget(),
    ),
  ),
);
