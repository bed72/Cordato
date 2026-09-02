import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cordato',
      theme: Themes.light,
      darkTheme: Themes.dark,
      themeMode: ThemeMode.system,
      routerConfig: ModularApp.routerConfigOf(context),
      builder: (context, child) =>
          ToastProviderWidget(child: child ?? const SizedBox.shrink()),
    );
  }
}
