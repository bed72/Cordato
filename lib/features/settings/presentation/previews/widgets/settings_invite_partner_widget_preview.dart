import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_invite_partner_widget.dart';

@CordatoPreview(
  group: 'Settings / Widgets',
  name: 'Convidar parceiro',
  size: Size(390.0, 160.0),
)
Widget previewSettingsInvitePartnerWidget() => Scaffold(
  body: Center(
    child: Padding(
      padding: const .all(16.0),
      child: SettingsInvitePartnerWidget(onInvitePartnerPressed: () {}),
    ),
  ),
);
