import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/previews/fakes/user_preview_repository.dart';

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
    PreviewResourceWidget<UserBloc Function()>(
      create: () =>
          () => UserBloc(repository: repository),
      dispose: (_) {},
      builder: (factory) => UserScreen(
        bloc: factory,
        onBackPressed: (_) {},
        onNamePressed: (_) async => null,
      ),
    );
