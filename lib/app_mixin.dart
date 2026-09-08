import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_widget.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

mixin AppMixin on State<AppWidget> {
  void navigateToDashboard() => _navigate(RouteEnum.dashboard.path);

  void recoverFromAuthenticationFailure(BuildContext context) {
    unawaited(_recoverFromAuthenticationFailure(context));
  }

  void _navigate(String path) =>
      widget.navigatorKey.currentContext?.navigate(path);

  Future<void> _recoverFromAuthenticationFailure(BuildContext context) async {
    await widget.signOut();
    if (!context.mounted) return;

    context.showToast(
      variant: .error,
      title: 'Link de acesso inválido',
      description: 'Este link expirou ou é inválido. Solicite um novo link.',
    );

    _navigate(RouteEnum.authenticationMagicLink.path);
  }
}
