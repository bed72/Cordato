import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';
import 'package:cordato/features/user/presentation/screens/edit/edit_user_screen.dart';

mixin EditUserScreenStateMixin on State<EditUserScreen> {
  late EditBloc bloc;
  String? nameFailure;
  late String name = widget.initialName;

  bool get canUpdate =>
      name.trim().isNotEmpty && name.trim() != widget.initialName.trim();

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
  }

  @override
  void didUpdateWidget(covariant EditUserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) return;
    unawaited(bloc.close());
    bloc = widget.bloc();
    nameFailure = null;
  }

  @override
  void dispose() {
    unawaited(bloc.close());
    super.dispose();
  }

  void onNameChanged(String value) {
    setState(() {
      name = value;
      nameFailure = null;
    });
  }

  void updateName() {
    if (!canUpdate || !bloc.state.canSubmit || bloc.isClosed) return;
    context.dismissKeyboard();
    setState(() => nameFailure = null);
    bloc.add(EditSubmittedEvent(name: name.trim()));
  }

  void handleUpdate(EditState state) {
    if (!mounted || bloc.isClosed) return;
    if (state case EditFailure(:final errors)) {
      final fieldErrors = errors.errors.where(
        (error) =>
            error.status == '422' && error.pointer == '/data/attributes/name',
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
      final remaining = errors.errors.where(
        (error) =>
            error.status != '422' || error.pointer != '/data/attributes/name',
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
      } else if (errors.errors.isEmpty) {
        context.showToast(
          variant: .error,
          title: 'Erro ao atualizar nome',
          description: 'Não foi possível atualizar o nome. Tente novamente.',
        );
      }
      return;
    }
    if (state case EditSuccess(:final user)) {
      context.showToast(
        variant: .success,
        title: 'Nome atualizado',
        description: 'Seu nome foi atualizado com sucesso.',
      );
      widget.onUpdated(context, user);
    }
  }
}
