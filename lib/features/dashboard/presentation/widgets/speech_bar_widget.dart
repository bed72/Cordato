import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/dashboard/presentation/widgets/expense_action_button_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/speech_controls_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_state.dart';

final class const SpeechBarWidget({
  super.key,
  required final double expansion,
  required final SpeechState state,
  required final VoidCallback onOpenExpense,
  required final VoidCallback onStartCapture,
  required final VoidCallback onCancelCapture,
  required final VoidCallback onSubmitCapture,
}) extends StatelessWidget {
  static const _collapsedSize = 48.0;
  static const _expandedHeight = 56.0;
  static const _horizontalMargin = 32.0;

  @override
  Widget build(BuildContext context) {
    final availableWidth = _availableWidth(context);
    final animatedWidth =
        _collapsedSize + (availableWidth - _collapsedSize) * expansion;
    final animatedHeight =
        _collapsedSize + (_expandedHeight - _collapsedSize) * expansion;

    final borderRadius = BorderRadius.lerp(
      context.radius.cornerRadius100,
      context.radius.cornerRadius300,
      expansion,
    )!;

    final content = _buildContent(availableWidth);

    return SizedBox(
      width: animatedWidth,
      height: animatedHeight,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: _backgroundColor(context),
          child: DecoratedBox(
            decoration: _surfaceDecoration(context),
            child: content,
          ),
        ),
      ),
    );
  }

  double _availableWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final safeAreaWidth = MediaQuery.paddingOf(context).horizontal;

    return (screenWidth - _horizontalMargin - safeAreaWidth).clamp(
      _collapsedSize,
      double.infinity,
    );
  }

  Color _backgroundColor(BuildContext context) {
    if (state is SpeechIdle) {
      return context.colors.primary;
    }

    final palette = Theme.of(context).extension<AppColors>()!;

    return palette.surfaceElevated.withValues(alpha: 245 / 255 * expansion);
  }

  BoxDecoration _surfaceDecoration(BuildContext context) {
    final borderColor = context.colors.outlineVariant.withValues(
      alpha: 144 / 255 * expansion,
    );

    return BoxDecoration(
      borderRadius: context.radius.cornerRadius300,
      border: Border.all(color: borderColor),
    );
  }

  Widget _buildContent(double availableWidth) => switch (state) {
    SpeechIdle() => ExpenseActionButtonWidget(
      onTap: onOpenExpense,
      onLongPress: onStartCapture,
    ),
    _ => _buildExpandedControls(availableWidth),
  };

  Widget _buildExpandedControls(double availableWidth) => OverflowBox(
    alignment: Alignment.bottomRight,
    minWidth: availableWidth,
    maxWidth: availableWidth,
    minHeight: _expandedHeight,
    maxHeight: _expandedHeight,
    child: Opacity(
      opacity: expansion,
      child: SpeechControlsWidget(
        state: state,
        onCancel: onCancelCapture,
        onSubmit: onSubmitCapture,
      ),
    ),
  );
}
