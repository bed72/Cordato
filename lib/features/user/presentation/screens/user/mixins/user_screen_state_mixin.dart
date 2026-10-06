import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';

mixin UserScreenStateMixin on State<UserScreen> {
  @override
  void initState() {
    super.initState();
    loadUser();
  }

  void loadUser() => widget.command.execute.run();

  Future<void> editName(UserEntity user) async {
    final updated = await widget.onNamePressed(user.name);
    if (!mounted || updated == null) return;
    loadUser();
  }

  String error(ErrorsEntity errors) => errors.errors
      .map((error) => error.detail ?? error.title ?? '...')
      .join('\n');
}
