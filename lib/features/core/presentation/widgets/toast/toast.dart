import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

enum ToastVariant { error, info, success, warning }

final class const ToastAction({
  required final String label,
  required final VoidCallback onPressed,
}) {}

final class const ToastPalette({
  required final Color background,
  required final Color foreground,
}) {}

final class const ToastData({
  required final int id,
  required final String title,
  final ToastAction? action,
  final Duration? duration,
  final String? description,
  final ToastVariant variant = .info,
}) {}

IconData getToastIcon(ToastVariant variant) => switch (variant) {
  .info => Icons.help_outline,
  .error => Icons.warning_amber_rounded,
  .success => Icons.check_circle_outline,
  .warning => Icons.warning_amber_rounded,
};

String getToastAccessibilityLabel(ToastVariant variant) => switch (variant) {
  .error => 'Erro',
  .warning => 'Aviso',
  .info => 'Informação',
  .success => 'Sucesso',
};

ToastPalette getToastPalette(BuildContext context, ToastVariant variant) {
  final colors = context.colors;
  final appColors = Theme.of(context).extension<AppColors>()!;

  return switch (variant) {
    .info => ToastPalette(
      background: colors.tertiaryContainer,
      foreground: colors.onTertiaryContainer,
    ),
    .error => ToastPalette(
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
    ),
    .success => ToastPalette(
      background: appColors.success,
      foreground: appColors.textOnSuccess,
    ),
    .warning => ToastPalette(
      background: appColors.warning,
      foreground: appColors.textOnWarning,
    ),
  };
}
