import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

enum ToastVariant { error, info, success, warning }

final class ToastAction {
  final String label;
  final VoidCallback onPressed;

  const ToastAction({required this.label, required this.onPressed});
}

final class ToastPalette {
  final Color background;
  final Color foreground;

  const ToastPalette({required this.background, required this.foreground});
}

final class ToastData {
  final int id;
  final String title;
  final ToastVariant variant;
  final Duration? duration;
  final String? description;
  final ToastAction? action;

  const ToastData({
    required this.id,
    required this.title,
    this.action,
    this.duration,
    this.description,
    this.variant = .info,
  });
}

IconData getToastIcon(ToastVariant variant) => switch (variant) {
  .info => Icons.info_outline,
  .error => Icons.error_outline,
  .success => Icons.check_circle_outline,
  .warning => Icons.warning_amber_outlined,
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
