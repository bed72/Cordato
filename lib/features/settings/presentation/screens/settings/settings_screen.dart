import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_section_widget.dart';

import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_state.dart';

import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_logout_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_app_bar_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/mixins/settings_screen_state_mixin.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_premium_badge_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_invite_partner_widget.dart';

final class const SettingsScreen({
  super.key,
  required final LogoutBloc Function() bloc,
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
    return BlocConsumer<LogoutBloc, LogoutState>(
      bloc: bloc,
      listener: (_, state) => handleLogout(state),
      builder: (_, state) => Scaffold(
        appBar: SettingsAppBarWidget(onBackPressed: widget.onBackPressed),
        body: SafeArea(
          child: Padding(
            padding: const .all(16.0),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const HeaderWidget(
                  title: 'Configurações',
                  description: 'Gerencie suas preferências.',
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        const SizedBox(height: 16.0),
                        MenuSectionWidget(
                          label: 'Casal',
                          child: SettingsInvitePartnerWidget(
                            onInvitePartnerPressed:
                                widget.onInvitePartnerPressed,
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        MenuSectionWidget(
                          label: 'Conta',
                          child: MenuCardWidget(
                            children: [
                              MenuItemWidget(
                                label: 'Dados pessoais',
                                icon: lucide.user,
                                onPressed: widget.onPersonalDataPressed,
                              ),
                              MenuItemWidget(
                                label: 'Subscrição',
                                icon: lucide.sparkles,
                                trailing: const SettingsPremiumBadgeWidget(),
                                onPressed: widget.onSubscriptionPressed,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        MenuSectionWidget(
                          label: 'Informações',
                          child: MenuCardWidget(
                            children: [
                              MenuItemWidget(
                                label: 'Termos de uso',
                                onPressed: widget.onTermsPressed,
                                icon: lucide.file_text,
                              ),
                              MenuItemWidget(
                                icon: lucide.shield_check,
                                label: 'Políticas de privacidade',
                                onPressed: widget.onPrivacyPressed,
                              ),
                              MenuItemWidget(
                                label: 'Ajuda',
                                icon: lucide.circle_help,
                                onPressed: widget.onHelpPressed,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SettingsLogoutWidget(
                  isLoading: state.isSubmitting,
                  onLogoutPressed: state.canSubmit
                      ? showLogoutConfirmation
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
