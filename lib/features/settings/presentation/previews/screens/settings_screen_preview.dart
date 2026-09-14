import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';

@CordatoPreview(
  group: 'Configurações / Telas',
  name: 'Configurações',
  size: cordatoPhonePreviewSize,
)
Widget previewSettingsScreen() => SettingsScreen(
  onBackPressed: (_) {},
  onHelpPressed: () {},
  onTermsPressed: () {},
  onLogoutPressed: () {},
  onPrivacyPressed: () {},
  onPersonalDataPressed: () {},
  onSubscriptionPressed: () {},
  onInvitePartnerPressed: () {},
);

@CordatoPreview(
  group: 'Configurações / Telas',
  name: 'Configurações compacta e desabilitada',
  size: Size(280.0, 520.0),
)
Widget previewDisabledCompactSettingsScreen() =>
    SettingsScreen(onBackPressed: (_) {});
