import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';

mixin UserScreenStateMixin on State<UserScreen> {
  @override
  void initState() {
    super.initState();
    widget.deleteCommand.execute.results.addListener(_handleDelete);
    loadUser();
  }

  @override
  void dispose() {
    widget.deleteCommand.execute.results.removeListener(_handleDelete);
    super.dispose();
  }

  void loadUser() => widget.command.execute.run();

  Future<void> showDeleteAccountConfirmation() async {
    if (widget.deleteCommand.execute.isRunning.value) return;
    await showConfirmationBottomSheetWidget(
      context: context,
      title: 'Deseja apagar sua conta?',
      subtitle: 'Esta ação é irreversível. Sua conta e seus dados serão apagados permanentemente.',
      onConfirm: () {
        if (widget.deleteCommand.execute.isRunning.value) return;
        widget.deleteCommand.execute.run();
      },
    );
  }

  void _handleDelete() {
    final data = widget.deleteCommand.execute.results.value;
    if (!mounted || data.isRunning) return;

    final rejected = switch (data.data) {
      Right(value: false) => true,
      _ => false,
    };

    if (data.hasError || rejected) {
      context.showToast(
        variant: .error,
        title: 'Erro ao apagar conta',
        description: 'Não foi possível apagar sua conta. Tente novamente.',
      );
      return;
    }

    if (data.data case Left(:final value)) {
      context.showToast(
        variant: .error,
        title: value.errors.firstOrNull?.title ?? 'Erro ao apagar conta',
        description: value.errors.isEmpty
            ? 'Não foi possível apagar sua conta. Tente novamente.'
            : value.errors
                  .map(
                    (error) =>
                        error.detail ??
                        'Não foi possível apagar sua conta. Tente novamente.',
                  )
                  .join('\n'),
      );
    }
  }

  Future<void> editName(UserEntity user) async {
    final updated = await widget.onNamePressed(user.name);
    if (!mounted || updated == null) return;
    loadUser();
  }

  String error(ErrorsEntity errors) => errors.errors
      .map((error) => error.detail ?? error.title ?? '...')
      .join('\n');
}
