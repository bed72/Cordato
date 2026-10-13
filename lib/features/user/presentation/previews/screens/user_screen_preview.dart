import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/user/presentation/previews/fakes/user_preview_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/delete_user_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/update_avatar_command.dart';

@CordatoPreview(
  group: 'User / Telas',
  name: 'Avatar / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'User / Telas',
  name: 'Avatar / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewUserAvatarScreen() => _screen(UserPreviewRepository());

@CordatoPreview(
  group: 'User / Telas',
  name: 'Falha ao salvar avatar automaticamente',
  size: cordatoPhonePreviewSize,
)
Widget previewUserAvatarFailureScreen() =>
    _screen(UserPreviewRepository(rejectAvatar: true));

Widget _screen(UserPreviewRepository repository) =>
    PreviewResourceWidget<
      ({UserCommand user, UpdateAvatarCommand avatar, DeleteUserCommand delete})
    >(
      create: () => (
        user: UserCommand(repository: repository),
        avatar: UpdateAvatarCommand(repository: repository),
        delete: DeleteUserCommand(repository: repository),
      ),
      dispose: (commands) => commands.delete.dispose(),
      builder: (commands) => UserScreen(
        command: commands.user,
        avatarCommand: commands.avatar,
        deleteCommand: commands.delete,
        onBackPressed: (_) {},
        onNamePressed: (_) async => null,
      ),
    );
