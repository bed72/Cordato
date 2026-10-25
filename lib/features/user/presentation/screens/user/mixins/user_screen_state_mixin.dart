import 'dart:math';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';

mixin UserScreenStateMixin on State<UserScreen> {
  late UserBloc bloc;
  Timer? _avatarSaveTimer;
  String? _pendingAvatarSeed;
  final _avatarRandom = Random.secure();

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
    bloc.add(const UserRequestedEvent());
  }

  @override
  void didUpdateWidget(covariant UserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) return;
    _cancelAvatar();
    unawaited(bloc.close());
    bloc = widget.bloc();
    bloc.add(const UserRequestedEvent());
  }

  @override
  void dispose() {
    _avatarSaveTimer?.cancel();
    unawaited(bloc.close());
    super.dispose();
  }

  String avatarSeed(UserEntity user) =>
      _pendingAvatarSeed ?? user.avatar ?? 'cordato-user-${user.id}';

  void generateAvatar(UserEntity user) {
    if (!bloc.state.canEdit) return;
    String seed;
    do {
      seed = List.generate(
        16,
        (_) => _avatarRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    } while (seed == avatarSeed(user));
    setState(() => _pendingAvatarSeed = seed);
    _avatarSaveTimer?.cancel();
    final owner = bloc;
    _avatarSaveTimer = Timer(const Duration(seconds: 2), () {
      _avatarSaveTimer = null;
      if (!mounted || owner != bloc || !owner.state.canEdit) return;
      owner.add(UserAvatarSubmittedEvent(seed: seed));
    });
  }

  void _cancelAvatar() {
    _avatarSaveTimer?.cancel();
    _avatarSaveTimer = null;
    _pendingAvatarSeed = null;
  }

  void loadUser() {
    if (!bloc.state.canLoad) return;
    setState(_cancelAvatar);
    bloc.add(const UserRequestedEvent());
  }

  void handleUser(UserState state) {
    if (!mounted || bloc.isClosed) return;
    switch (state) {
      case UserAvatarSuccess():
        setState(() => _pendingAvatarSeed = null);
        context.showToast(
          variant: .success,
          title: 'Avatar atualizado',
          description: 'Seu novo avatar foi salvo com sucesso.',
        );
      case UserAvatarFailure(:final errors):
        context.showToast(
          variant: .error,
          description: error(errors),
          title: 'Não foi possível salvar o avatar',
        );
      case UserDeleteFailure(:final errors):
        context.showToast(
          variant: .error,
          title: errors.errors.firstOrNull?.title ?? 'Erro ao apagar conta',
          description: errors.errors.isEmpty
              ? 'Não foi possível apagar sua conta. Tente novamente.'
              : errors.errors
                    .map(
                      (error) =>
                          error.detail ??
                          'Não foi possível apagar sua conta. Tente novamente.',
                    )
                    .join('\n'),
        );
      default:
        break;
    }
  }

  Future<void> showDeleteAccountConfirmation() async {
    final owner = bloc;
    if (!owner.state.canDelete) return;
    await showConfirmationBottomSheetWidget(
      context: context,
      title: 'Deseja apagar sua conta?',
      subtitle: 'Esta ação é irreversível. Sua conta e seus dados serão apagados permanentemente.',
      onConfirm: () {
        if (!mounted ||
            owner != bloc ||
            owner.isClosed ||
            !owner.state.canDelete) {
          return;
        }
        setState(_cancelAvatar);
        owner.add(const UserDeleteRequestedEvent());
      },
    );
  }

  Future<void> editName(UserEntity user) async {
    final owner = bloc;
    if (!owner.state.canEdit) return;
    setState(_cancelAvatar);
    final updated = await widget.onNamePressed(user.name);
    if (!mounted || owner != bloc || owner.isClosed || updated == null) return;
    loadUser();
  }

  String error(ErrorsEntity errors) => errors.errors.isEmpty
      ? 'Não foi possível processar a resposta.'
      : errors.errors
            .map(
              (error) =>
                  error.detail ??
                  error.title ??
                  'Não foi possível processar a resposta.',
            )
            .join('\n');
}
