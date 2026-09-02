import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/radius_theme.dart';

extension BuildContextCommonExtension on BuildContext {
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
  double get bottom => MediaQuery.of(this).viewInsets.bottom;

  bool get isDark => Theme.of(this).brightness == .dark;

  ColorScheme get colors => Theme.of(this).colorScheme;

  TargetPlatform get platform => Theme.of(this).platform;

  TextTheme get typography => Theme.of(this).textTheme;
  CornerRadiusToken get radius =>
      Theme.of(this).extension<CornerRadiusToken>()!;
}
