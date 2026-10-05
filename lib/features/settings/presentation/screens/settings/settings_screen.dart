import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_card_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_item_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_header_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_logout_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_app_bar_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_section_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_invite_partner_widget.dart';

import 'package:cordato/features/authentication/presentation/commands/logout_command.dart';
import 'package:cordato/features/settings/presentation/screens/settings/mixins/settings_screen_state_mixin.dart';

final class const SettingsScreen({
  super.key,
  required final LogoutCommand command,
  required final ValueChanged<BuildContext> onBackPressed,
  final VoidCallback? onHelpPressed,
  final VoidCallback? onTermsPressed,
  final VoidCallback? onPrivacyPressed,
  final VoidCallback? onPersonalDataPressed,
  final VoidCallback? onSubscriptionPressed,
  final VoidCallback? onInvitePartnerPressed,
}) extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends State<SettingsScreen>
    with SettingsScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsAppBarWidget(onBackPressed: widget.onBackPressed),
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
                        onInvitePartnerPressed: widget.onInvitePartnerPressed,
                      ),
                      const SizedBox(height: 24.0),
                      const SettingsSectionWidget(label: 'Conta'),
                      const SizedBox(height: 8.0),
                      SettingsCardWidget(
                        children: [
                          SettingsItemWidget(
                            label: 'Dados pessoais',
                            icon: Icons.person_outline,
                            onPressed: widget.onPersonalDataPressed,
                          ),
                          SettingsItemWidget(
                            isPremium: true,
                            label: 'Subscrição',
                            icon: Icons.star_outline,
                            onPressed: widget.onSubscriptionPressed,
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
                            onPressed: widget.onTermsPressed,
                            icon: Icons.description_outlined,
                          ),
                          SettingsItemWidget(
                            icon: Icons.shield_outlined,
                            label: 'Políticas de privacidade',
                            onPressed: widget.onPrivacyPressed,
                          ),
                          SettingsItemWidget(
                            label: 'Ajuda',
                            icon: Icons.help_outline,
                            onPressed: widget.onHelpPressed,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              CommandBuilder(
                command: widget.command.execute,
                whileRunning: (_, _, _) => const SettingsLogoutWidget(
                  onLogoutPressed: null,
                  isLoading: true,
                ),
                onSuccess: (_, _) => SettingsLogoutWidget(
                  onLogoutPressed: showLogoutConfirmation,
                ),
                onError: (_, _, _, _) => SettingsLogoutWidget(
                  onLogoutPressed: showLogoutConfirmation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
