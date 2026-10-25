import 'package:material_ui/material_ui.dart';

extension ButtonStyleExtension on ButtonStyle {
  ButtonStyle get loadingStyle => copyWith(
    backgroundColor: WidgetStatePropertyAll(backgroundColor?.resolve({})),
    foregroundColor: WidgetStatePropertyAll(foregroundColor?.resolve({})),
    iconColor: WidgetStatePropertyAll(iconColor?.resolve({})),
    side: WidgetStatePropertyAll(side?.resolve({})),
  );
}
