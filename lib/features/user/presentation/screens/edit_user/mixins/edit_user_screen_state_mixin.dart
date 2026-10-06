import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/user/presentation/screens/edit_user/edit_user_screen.dart';

mixin EditUserScreenStateMixin on State<EditUserScreen> {
  String? nameFailure;
  late String name = widget.initialName;

  bool get canUpdate =>
      name.trim().isNotEmpty && name.trim() != widget.initialName.trim();

  @override
  void initState() {
    super.initState();
    widget.command.execute.results.addListener(_handleUpdate);
  }

  @override
  void dispose() {
    widget.command.execute.results.removeListener(_handleUpdate);
    super.dispose();
  }

  void onNameChanged(String value) {
    setState(() {
      name = value;
      nameFailure = null;
    });
  }

  void updateName() {
    if (!canUpdate || widget.command.execute.isRunning.value) return;
    context.dismissKeyboard();
    setState(() => nameFailure = null);
    widget.command.execute.run(name.trim());
  }

  void _handleUpdate() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

    if (data.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao atualizar nome',
        description: 'Não foi possível atualizar o nome. Tente novamente.',
      );
      return;
    }

    if (data.data case Left(:final value)) {
      final fieldErrors = value.errors.where(
        (error) => error.pointer == '/data/attributes/name',
      );

      setState(() {
        nameFailure = fieldErrors.isEmpty
            ? null
            : fieldErrors
                  .map(
                    (error) => error.detail ?? error.title ?? 'Nome inválido.',
                  )
                  .join('\n');
      });

      final remaining = value.errors.where(
        (error) => error.pointer != '/data/attributes/name',
      );

      if (remaining.isNotEmpty) {
        context.showToast(
          variant: .error,
          title: remaining.first.title ?? 'Erro ao atualizar nome',
          description: remaining
              .map(
                (error) => error.detail ?? 'Não foi possível atualizar o nome.',
              )
              .join('\n'),
        );
      }
      return;
    }

    if (data.data case Right(:final value)) {
      context.showToast(
        variant: .success,
        title: 'Nome atualizado',
        description: 'Seu nome foi atualizado com sucesso.',
      );

      widget.onUpdated(context, value);
    }
  }
}
