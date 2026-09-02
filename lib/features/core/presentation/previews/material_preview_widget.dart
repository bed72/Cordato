import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';

class MaterialPreviewWidget extends StatelessWidget {
  final Widget child;
  final ThemeMode? themeMode;

  const MaterialPreviewWidget({super.key, required this.child, this.themeMode});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Themes.light,
      darkTheme: Themes.dark,
      themeMode: themeMode ?? .system,
      debugShowCheckedModeBanner: false,
      home: child,
    );
  }
}
