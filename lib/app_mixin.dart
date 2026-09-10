import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_widget.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

mixin AppMixin on State<AppWidget> {
  void navigateToWelcome() => _navigate(RouteEnum.welcome.path);

  void navigateToDashboard() => _navigate(RouteEnum.dashboard.path);

  void _navigate(String path) =>
      widget.navigatorKey.currentContext?.navigate(path);
}
