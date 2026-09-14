import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/settings/presentation/widgets/settings_card_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_item_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_header_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_logout_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_app_bar_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_section_widget.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_invite_partner_widget.dart';

final class SettingsScreen extends StatelessWidget {
  final ValueChanged<BuildContext> onBackPressed;
  final VoidCallback? onHelpPressed;
  final VoidCallback? onTermsPressed;
  final VoidCallback? onLogoutPressed;
  final VoidCallback? onPrivacyPressed;
  final VoidCallback? onPersonalDataPressed;
  final VoidCallback? onSubscriptionPressed;
  final VoidCallback? onInvitePartnerPressed;

  const SettingsScreen({
    super.key,
    required this.onBackPressed,
    this.onInvitePartnerPressed,
    this.onPersonalDataPressed,
    this.onSubscriptionPressed,
    this.onTermsPressed,
    this.onPrivacyPressed,
    this.onHelpPressed,
    this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsAppBarWidget(onBackPressed: onBackPressed),
      body: SafeArea(
        child: Padding(
          padding: const .all(16.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const SettingsHeaderWidget(),
              const SizedBox(height: 8.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const SizedBox(height: 16.0),
                      const SettingsSectionWidget(label: 'Casal'),
                      const SizedBox(height: 8.0),
                      SettingsInvitePartnerWidget(
                        onInvitePartnerPressed: onInvitePartnerPressed,
                      ),
                      const SizedBox(height: 24.0),
                      const SettingsSectionWidget(label: 'Conta'),
                      const SizedBox(height: 8.0),
                      SettingsCardWidget(
                        children: [
                          SettingsItemWidget(
                            label: 'Dados pessoais',
                            icon: Icons.person_outline,
                            onPressed: onPersonalDataPressed,
                          ),
                          SettingsItemWidget(
                            isPremium: true,
                            label: 'Subscrição',
                            icon: Icons.star_outline,
                            onPressed: onSubscriptionPressed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24.0),
                      const SettingsSectionWidget(label: 'Informações'),
                      const SizedBox(height: 8.0),
                      SettingsCardWidget(
                        children: [
                          SettingsItemWidget(
                            label: 'Termos de uso',
                            onPressed: onTermsPressed,
                            icon: Icons.description_outlined,
                          ),
                          SettingsItemWidget(
                            icon: Icons.shield_outlined,
                            onPressed: onPrivacyPressed,
                            label: 'Políticas de privacidade',
                          ),
                          SettingsItemWidget(
                            label: 'Ajuda',
                            icon: Icons.help_outline,
                            onPressed: onHelpPressed,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SettingsLogoutWidget(onLogoutPressed: onLogoutPressed),
            ],
          ),
        ),
      ),
    );
  }
}
