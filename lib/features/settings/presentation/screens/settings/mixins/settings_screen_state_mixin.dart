import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_state.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';

import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';

mixin SettingsScreenStateMixin on State<SettingsScreen> {
  late LogoutBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) return;
    unawaited(bloc.close());
    bloc = widget.bloc();
  }

  @override
  void dispose() {
    unawaited(bloc.close());
    super.dispose();
  }

  Future<void> showLogoutConfirmation() async {
    final owner = bloc;
    if (!owner.state.canSubmit) return;
    await showConfirmationBottomSheetWidget(
      context: context,
      confirmLabel: 'Sair',
      title: 'Realmente deseja sair?',
      subtitle: 'Ao sair da sua conta, você precisará fazer login novamente para acessar o Trocado.',
      onConfirm: () {
        if (!mounted ||
            !identical(bloc, owner) ||
            owner.isClosed ||
            !owner.state.canSubmit) {
          return;
        }
        owner.add(const LogoutRequestedEvent());
      },
    );
  }

  void handleLogout(LogoutState state) {
    if (!mounted || bloc.isClosed || state is! LogoutFailure) return;
    if (state case LogoutFailure(:final errors) when errors.errors.isNotEmpty) {
      context.showToast(
        variant: .error,
        title: errors.errors.first.title ?? 'Erro ao sair',
        description: errors.errors
            .map(
              (error) =>
                  error.detail ?? 'Não foi possível sair. Tente novamente.',
            )
            .join('\n'),
      );
      return;
    }
    context.showToast(
      variant: .error,
      title: 'Erro ao sair',
      description: 'Não foi possível sair. Tente novamente.',
    );
  }
}
