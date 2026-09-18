import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

final class const MaterialPreviewWidget({
  super.key,
  required final Widget child,
  final ThemeMode? themeMode,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Themes.light,
      darkTheme: Themes.dark,
      themeMode: themeMode ?? .system,
      locale: const Locale('pt', 'BR'),
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (_, child) =>
          ToastProviderWidget(child: child ?? const SizedBox.shrink()),
      home: child,
    );
  }
}
