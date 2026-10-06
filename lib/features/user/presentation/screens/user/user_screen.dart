import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';

import 'package:cordato/features/user/presentation/screens/user/widgets/user_avatar_widget.dart';

import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_app_bar_widget.dart';

final class const UserScreen({
  super.key,
  required final String name,
  required final String email,
  required final VoidCallback onNamePressed,
  required final ValueChanged<BuildContext> onBackPressed,
  final String? imageSource,
  final VoidCallback? onPhotoPressed,
  final VoidCallback? onDeletePressed,
}) extends StatelessWidget {
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
              const HeaderWidget(
                title: 'Dados pessoais',
                description: 'Gerencie os dados da sua conta.',
              ),
              const SizedBox(height: 24.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      Center(
                        child: UserAvatarWidget(
                          name: name,
                          imageSource: imageSource,
                          onPhotoPressed: onPhotoPressed,
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      MenuCardWidget(
                        children: [
                          MenuItemWidget(
                            value: name,
                            label: 'Nome',
                            height: 64.0,
                            spacing: 12.0,
                            onPressed: onNamePressed,
                            icon: Icons.person_outline,
                          ),
                          MenuItemWidget(
                            value: email,
                            height: 64.0,
                            spacing: 12.0,
                            label: 'E-mail',
                            showChevron: false,
                            disabledOpacity: 0.5,
                            icon: Icons.mail_outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              DangerButtonWidget(
                label: 'Excluir conta',
                onTap: onDeletePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
