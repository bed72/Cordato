import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/screens/error_screen.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

import 'package:cordato/features/user/presentation/extensions/user_presentation_extension.dart';

import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/user/widgets/user_avatar_widget.dart';
import 'package:cordato/features/user/presentation/screens/user/widgets/user_skeleton_widget.dart';
import 'package:cordato/features/user/presentation/screens/user/mixins/user_screen_state_mixin.dart';

import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_app_bar_widget.dart';

final class const UserScreen({
  super.key,
  required final UserBloc Function() bloc,
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
    return BlocConsumer<UserBloc, UserState>(
      bloc: bloc,
      listener: (_, state) => handleUser(state),
      builder: (_, state) {
        if (state case UserFailure(:final errors)) {
          return ErrorScreen(
            onAction: loadUser,
            description: error(errors),
            actionLabel: 'Tentar novamente',
            title: 'Não foi possível carregar seus dados.',
            appBar: SettingsAppBarWidget(onBackPressed: widget.onBackPressed),
          );
        }
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
                    description: 'Personalize seu perfil neste dispositivo.',
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: state.user != null
                        ? _buildUser(state.user!, state)
                        : ExcludeSemantics(
                            child: IgnorePointer(
                              child: UserSkeletonWidget(
                                child: _buildUser(
                                  const UserEntity(name: 'Nome do usuário'),
                                  state,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  SingleChildScrollView _buildUser(UserEntity currentUser, UserState state) =>
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Center(
              child: UserAvatarWidget(
                name: currentUser.displayName,
                seed: avatarSeed(currentUser),
                onPressed: state.canEdit
                    ? () => generateAvatar(currentUser)
                    : null,
              ),
            ),
            const SizedBox(height: 16.0),
            MenuCardWidget(
              children: [
                MenuItemWidget(
                  label: 'Nome',
                  height: 64.0,
                  spacing: 12.0,
                  value: currentUser.displayName,
                  icon: Icons.person_outline,
                  onPressed: state.canEdit ? () => editName(currentUser) : null,
                ),
              ],
            ),
          ],
        ),
      );
}
