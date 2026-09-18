import 'package:material_ui/material_ui.dart';

enum ShakeAnimationConstant { horizontal, vertical }

class const ShakeAnimation({
  super.key,
  required final Widget child,
  required final bool shake,
  final double offset = 6,
  final int seconds = 2,
  final ShakeAnimationConstant direction = .horizontal,
}) extends StatefulWidget {
  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    );

    final items = <TweenSequenceItem<double>>[];
    items.add(TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 1));

    for (int i = 0; i < 12; i++) {
      final end = (i % 2 == 0) ? 1.0 : 0.0;
      final begin = (i % 2 == 0) ? 0.0 : -1.0;

      items.add(
        TweenSequenceItem(
          weight: 2,
          tween: Tween(begin: begin, end: end),
        ),
      );
    }

    items.add(TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 1));

    _animation = TweenSequence(
      items,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shake && !_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        final value = _animation.value * widget.offset;

        return Transform.translate(
          offset: widget.direction == .horizontal
              ? Offset(value, 0)
              : Offset(0, value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
