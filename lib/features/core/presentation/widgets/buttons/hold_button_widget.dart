import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/animations/animation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';

class const HoldButtonWidget({
  super.key,
  required final String label,
  required final VoidCallback? onTap,
  final VoidCallback? onHoldComplete,
  final bool isLoading = false,
  final Duration holdDuration = const Duration(milliseconds: 1500),
}) extends StatefulWidget {
  @override
  State<HoldButtonWidget> createState() => HoldButtonWidgetState();
}

class HoldButtonWidgetState extends State<HoldButtonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _enabled => widget.onTap != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _controller.addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != .completed) return;
    _controller.reset();
    widget.onHoldComplete?.call();
  }

  void _onTap() {
    if (!_enabled) return;
    Future.delayed(const Duration(milliseconds: 30), widget.onTap);
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (!_enabled || widget.onHoldComplete == null) return;
    _controller.forward();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_controller.isAnimating) _controller.reverse();
  }

  void _onLongPressCancel() {
    if (_controller.isAnimating) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return BounceWidget.withoutOnPress(
      child: GestureDetector(
        onLongPressEnd: _onLongPressEnd,
        onLongPressStart: _onLongPressStart,
        onLongPressCancel: _onLongPressCancel,
        child: SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: .circular(16.0),
            child: Stack(
              children: [_buildBase(context), _buildOverlay(context)],
            ),
          ),
        ),
      ),
    );
  }

  SizedBox _buildBase(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _enabled ? _onTap : null,
      child: SwitcherAnimation(
        child: widget.isLoading
            ? CircularProgressIndicatorWidget(
                key: const ValueKey('loading'),
                width: 20.0,
                height: 20.0,
                color: context.isDark
                    ? context.colors.onPrimaryContainer
                    : context.colors.onPrimary,
              )
            : Text(key: const ValueKey('content'), widget.label),
      ),
    ),
  );

  Widget _buildOverlay(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          if (_controller.value == 0) return const SizedBox.shrink();

          return FractionallySizedBox(
            alignment: .centerLeft,
            widthFactor: _controller.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: .circular(16.0),
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          );
        },
      ),
    ),
  );
}
