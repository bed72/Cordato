import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/update_avatar_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/delete_user_command.dart';
import 'package:cordato/features/user/presentation/screens/user/mixins/user_screen_state_mixin.dart';

import 'package:cordato/features/user/presentation/screens/user/widgets/user_avatar_widget.dart';
import 'package:cordato/features/user/presentation/screens/user/widgets/user_skeleton_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_app_bar_widget.dart';

final class const UserScreen({
  super.key,
  required final UserCommand command,
  required final UpdateAvatarCommand avatarCommand,
  required final DeleteUserCommand deleteCommand,
  required final ValueChanged<BuildContext> onBackPressed,
  required final Future<UserEntity?> Function(String name) onNamePressed,
}) extends StatefulWidget {
  @override
  State<UserScreen> createState() => _UserScreenState();
}

final class _UserScreenState extends State<UserScreen>
    with UserScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsAppBarWidget(onBackPressed: widget.onBackPressed),
      body: SafeArea(
        child: Padding(
          padding: const .all(16.0),
          child: Column(
            spacing: 16,
            crossAxisAlignment: .stretch,
            children: [
              const HeaderWidget(
                title: 'Dados pessoais',
                description: 'Gerencie os dados da sua conta.',
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: CommandBuilder<void, GetByIdRepositoryType?>(
                  command: widget.command.execute,
                  whileRunning: (_, _, _) => _buildSkeleton(),
                  onError: (_, _, _, _) => _buildError(.unknown()),
                  onSuccess: (_, _) => switch (widget.command.execute.value) {
                    Right(:final value) =>
                      CommandBuilder<String, UpdateRepositoryType?>(
                        command: widget.avatarCommand.execute,
                        whileRunning: (_, _, _) =>
                            _buildUser(avatarUser ?? value),
                        onSuccess: (_, _) => _buildUser(avatarUser ?? value),
                        onError: (_, _, _, _) =>
                            _buildUser(avatarUser ?? value),
                      ),
                    Left(:final value) => _buildError(value),
                    null => _buildSkeleton(),
                  },
                ),
              ),
              const SizedBox(height: 8.0),
              CommandBuilder(
                command: widget.deleteCommand.execute,
                whileRunning: (_, _, _) => const DangerButtonWidget(
                  label: 'Excluir conta',
                  isLoading: true,
                  onTap: null,
                ),
                onSuccess: (_, _) => DangerButtonWidget(
                  label: 'Excluir conta',
                  onTap: showDeleteAccountConfirmation,
                ),
                onError: (_, _, _, _) => DangerButtonWidget(
                  label: 'Excluir conta',
                  onTap: showDeleteAccountConfirmation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  UserSkeletonWidget _buildSkeleton() => UserSkeletonWidget(
    child: _buildUser(
      const UserEntity(
        id: '72',
        status: 'active',
        name: 'Nome do usuário',
        email: 'usuario@exemplo.com',
      ),
    ),
  );

  SingleChildScrollView _buildUser(UserEntity user) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Center(
          child: UserAvatarWidget(
            name: user.name,
            seed: avatarSeed(user),
            onPressed: isSavingAvatar || widget.command.execute.isRunning.value
                ? null
                : () => generateAvatar(user),
          ),
        ),
        const SizedBox(height: 16.0),
        MenuCardWidget(
          children: [
            MenuItemWidget(
              label: 'Nome',
              height: 64.0,
              spacing: 12.0,
              value: user.name,
              icon: Icons.person_outline,
              onPressed: isSavingAvatar ? null : () => editName(user),
            ),
            MenuItemWidget(
              height: 64.0,
              spacing: 12.0,
              label: 'E-mail',
              value: user.email,
              showChevron: false,
              disabledOpacity: 0.5,
              icon: Icons.mail_outline,
            ),
          ],
        ),
      ],
    ),
  );

  Center _buildError(ErrorsEntity errors) => Center(
    child: SingleChildScrollView(
      child: Column(
        spacing: 16.0,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            'Não foi possível carregar seus dados.',
            textAlign: .center,
            style: context.typography.titleMedium,
          ),
          Text(
            error(errors),
            textAlign: .center,
            style: context.typography.bodyMedium,
          ),
          ElevatedButtonWidget(label: 'Tentar novamente', onTap: loadUser),
        ],
      ),
    ),
  );
}
