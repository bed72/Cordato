import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/user/presentation/validators/name_validation.dart';

import 'package:cordato/features/user/presentation/screens/edit/edit_screen.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';
import 'package:cordato/features/user/presentation/formatters/user_error_message_formatter.dart';

mixin EditScreenStateMixin on State<EditScreen> {
  late EditBloc bloc;
  String? nameFailure;
  late String name = widget.initialName;
  final nameValidation = const NameValidation();

  bool get canUpdate =>
      nameValidation(name) is Valid<String> &&
      name.trim() != widget.initialName.trim();

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
  }

  @override
  void didUpdateWidget(covariant EditScreen oldWidget) {
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
      nameFailure = switch (nameValidation(value)) {
        Invalid(:final message) => message,
        Valid() => null,
      };
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
      final fieldErrors = errors.errors.where(nameValidation.isFieldError);
      setState(() {
        nameFailure = fieldErrors.isEmpty
            ? null
            : fieldErrors
                  .map(
                    (error) => UserErrorMessageFormatter.format(
                      error,
                      fallback: 'Confira o nome informado.',
                    ),
                  )
                  .join('\n');
      });
      final remaining = errors.errors.where(
        (error) => !nameValidation.isFieldError(error),
      );
      if (remaining.isNotEmpty) {
        context.showToast(
          variant: .error,
          title: 'Erro ao atualizar nome',
          description: remaining
              .map(
                (error) => UserErrorMessageFormatter.format(
                  error,
                  fallback:
                      'Não foi possível atualizar o nome. Tente novamente.',
                ),
              )
              .toSet()
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
