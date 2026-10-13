import 'dart:math';
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';

mixin UserScreenStateMixin on State<UserScreen> {
  UserEntity? avatarUser;
  Timer? _avatarSaveTimer;
  String? _pendingAvatarSeed;
  final _avatarRandom = Random.secure();

  bool get isSavingAvatar => widget.avatarCommand.execute.isRunning.value;

  String avatarSeed(UserEntity user) =>
      _pendingAvatarSeed ?? user.avatar ?? 'cordato-user-${user.id}';

  void generateAvatar(UserEntity user) {
    if (isSavingAvatar || widget.deleteCommand.execute.isRunning.value) return;
    String seed;
    do {
      seed = List.generate(
        16,
        (_) => _avatarRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    } while (seed == avatarSeed(user));
    setState(() => _pendingAvatarSeed = seed);
    _avatarSaveTimer?.cancel();
    _avatarSaveTimer = Timer(const Duration(seconds: 2), () {
      _avatarSaveTimer = null;
      _saveAvatar();
    });
  }

  void _saveAvatar() {
    final seed = _pendingAvatarSeed;
    if (!mounted ||
        seed == null ||
        isSavingAvatar ||
        widget.deleteCommand.execute.isRunning.value) {
      return;
    }
    widget.avatarCommand.execute.run(seed);
  }

  @override
  void initState() {
    super.initState();
    widget.deleteCommand.execute.results.addListener(_handleDelete);
    widget.avatarCommand.execute.results.addListener(_handleAvatarUpdate);
    loadUser();
  }

  @override
  void dispose() {
    _avatarSaveTimer?.cancel();
    widget.deleteCommand.execute.results.removeListener(_handleDelete);
    widget.avatarCommand.execute.results.removeListener(_handleAvatarUpdate);
    widget.avatarCommand.dispose();
    widget.command.dispose();
    super.dispose();
  }

  void loadUser() {
    avatarUser = null;
    widget.command.execute.run();
  }

  void _handleAvatarUpdate() {
    final result = widget.avatarCommand.execute.results.value;
    if (!mounted || result.isRunning) return;
    if (result.data case Right(:final value)) {
      if (!result.hasError &&
          value.avatar == _pendingAvatarSeed &&
          value.avatar != null) {
        setState(() {
          avatarUser = value;
          _pendingAvatarSeed = null;
        });
        context.showToast(
          variant: .success,
          title: 'Avatar atualizado',
          description: 'Seu novo avatar foi salvo com sucesso.',
        );
        return;
      }
    }
    final errors = switch (result.data) {
      Left(:final value) => value,
      _ => ErrorsEntity.unknown(),
    };
    context.showToast(
      variant: .error,
      title: 'Não foi possível salvar o avatar',
      description: error(errors),
    );
  }

  Future<void> showDeleteAccountConfirmation() async {
    if (isSavingAvatar || widget.deleteCommand.execute.isRunning.value) return;
    await showConfirmationBottomSheetWidget(
      context: context,
      title: 'Deseja apagar sua conta?',
      subtitle: 'Esta ação é irreversível. Sua conta e seus dados serão apagados permanentemente.',
      onConfirm: () {
        if (isSavingAvatar || widget.deleteCommand.execute.isRunning.value) {
          return;
        }
        _avatarSaveTimer?.cancel();
        _avatarSaveTimer = null;
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
    final command = widget.command;
    final updated = await widget.onNamePressed(user.name);
    if (!mounted || command != widget.command || updated == null) return;
    loadUser();
  }

  String error(ErrorsEntity errors) => errors.errors
      .map((error) => error.detail ?? error.title ?? '...')
      .join('\n');

  @override
  void didUpdateWidget(covariant UserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarCommand != widget.avatarCommand ||
        oldWidget.command != widget.command ||
        oldWidget.deleteCommand != widget.deleteCommand) {
      _avatarSaveTimer?.cancel();
      _avatarSaveTimer = null;
      _pendingAvatarSeed = null;
    }
    if (oldWidget.avatarCommand != widget.avatarCommand) {
      oldWidget.avatarCommand.execute.results.removeListener(
        _handleAvatarUpdate,
      );
      oldWidget.avatarCommand.dispose();
      widget.avatarCommand.execute.results.addListener(_handleAvatarUpdate);
    }
    if (oldWidget.deleteCommand != widget.deleteCommand) {
      oldWidget.deleteCommand.execute.results.removeListener(_handleDelete);
      widget.deleteCommand.execute.results.addListener(_handleDelete);
    }
    if (oldWidget.command != widget.command) {
      oldWidget.command.dispose();
      _pendingAvatarSeed = null;
      loadUser();
    }
  }
}
