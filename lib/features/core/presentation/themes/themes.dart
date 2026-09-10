import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/core/presentation/themes/radius_theme.dart';

abstract final class Themes {
  static final light = _build(
    colors: lightColors,
    colorScheme: lightColorScheme,
    splashFactory: NoSplash.splashFactory,
  );

  static final dark = _build(
    colors: darkColors,
    colorScheme: darkColorScheme,
    splashFactory: NoSplash.splashFactory,
  );

  static ThemeData _build({
    required AppColors colors,
    required ColorScheme colorScheme,
    InteractiveInkFeatureFactory? splashFactory,
  }) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: colorScheme,
    splashFactory: splashFactory,
    visualDensity: .standard,
    scaffoldBackgroundColor: colors.background,
    extensions: <ThemeExtension<dynamic>>[radius, colors],
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: colors.selection,
    ),
    navigationRailTheme: const NavigationRailThemeData(useIndicator: true),
    appBarTheme: AppBarTheme(
      elevation: 0.0,
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(
      elevation: 0.0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0.0,
      color: colors.surface,
      clipBehavior: .antiAlias,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: .all(.circular(14.0))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0.0,
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
        minimumSize: const Size(56.0, 56.0),
        shape: const RoundedRectangleBorder(
          borderRadius: .all(.circular(14.0)),
        ),
        textStyle: TextStyle(
          fontSize: 15.0,
          height: 20 / 15,
          fontWeight: .w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            minimumSize: const Size(56.0, 56.0),
            shape: const RoundedRectangleBorder(
              borderRadius: .all(.circular(14.0)),
            ),
            textStyle: TextStyle(
              fontSize: 15.0,
              height: 20 / 15,
              fontWeight: .w600,
            ),
          ).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? colorScheme.onSurface.withValues(alpha: .38)
                  : colors.primary,
            ),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? colorScheme.onSurface.withValues(alpha: .38)
                    : colorScheme.primary,
              ),
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(56.0, 56.0),
        foregroundColor: colorScheme.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: .all(.circular(14.0)),
        ),
        textStyle: TextStyle(
          fontSize: 15.0,
          height: 20 / 15,
          fontWeight: .w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      contentPadding: const .symmetric(horizontal: 0.0),
      border: OutlineInputBorder(
        borderRadius: const .all(.circular(14.0)),
        borderSide: BorderSide(color: colors.border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 0.0,
      contentPadding: .symmetric(vertical: 8.0, horizontal: 16.0),
    ),
  );
}
