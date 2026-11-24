import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_section_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_app_bar_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_support_badge_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/export_expenses_widget.dart';

final class const SettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsAppBarWidget(onBackPressed: (context) => context.pop()),
      body: SafeArea(
        child: Padding(
          padding: const .all(16.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const HeaderWidget(
                title: 'Configurações',
                description: 'Seu perfil e os dados deste dispositivo.',
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const SizedBox(height: 16.0),
                      MenuSectionWidget(
                        label: 'Perfil local',
                        child: MenuCardWidget(
                          children: [
                            MenuItemWidget(
                              label: 'Dados pessoais',
                              icon: Icons.person_outline,
                              onPressed: () =>
                                  context.pushNamed(RouteEnum.user.path),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      const MenuSectionWidget(
                        label: 'Dados',
                        child: MenuCardWidget(
                          children: [ExportExpensesWidget()],
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      MenuSectionWidget(
                        label: 'Informações',
                        child: MenuCardWidget(
                          children: [
                            MenuItemWidget(
                              label: 'Termos de uso',
                              icon: Icons.receipt_long_outlined,
                              onPressed: () => context.pushNamed(
                                RouteEnum.informationTerms.path,
                              ),
                            ),
                            MenuItemWidget(
                              label: 'Política de Privacidade',
                              icon: Icons.verified_user_outlined,
                              onPressed: () => context.pushNamed(
                                RouteEnum.informationPrivacy.path,
                              ),
                            ),
                            MenuItemWidget(
                              label: 'Ajuda',
                              icon: Icons.help_outline,
                              onPressed: () => context.pushNamed(
                                RouteEnum.informationHelp.path,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      MenuSectionWidget(
                        label: 'Apoio',
                        child: MenuCardWidget(
                          children: [
                            MenuItemWidget(
                              label: 'Pague-me um café',
                              icon: Icons.coffee_outlined,
                              onPressed: () => context.pushNamed(
                                RouteEnum.settingsSupport.path,
                              ),
                              trailing: const SettingsSupportBadgeWidget(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
