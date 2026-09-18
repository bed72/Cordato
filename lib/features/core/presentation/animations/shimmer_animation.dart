import 'package:material_ui/material_ui.dart';

class const ShimmerAnimation({
  super.key,
  required final Widget child,
  final BorderRadiusGeometry radius = .zero,
  final Duration pause = const Duration(milliseconds: 5000),
  final Duration duration = const Duration(milliseconds: 2000),
}) extends StatefulWidget {
  @override
  State<ShimmerAnimation> createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends State<ShimmerAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      await _controller.forward(from: 0);
      await Future.delayed(widget.pause);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.radius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => ShaderMask(
          blendMode: BlendMode.lighten,
          shaderCallback: (bounds) {
            final width = bounds.width;
            final height = bounds.height;

            final transverseLight =
                _controller.value * (width + height) - height;

            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.4, 0.5, 0.6],
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.04),
              ],
            ).createShader(Rect.fromLTWH(transverseLight, 0, width, height));
          },
          child: widget.child,
        ),
      ),
    );
  }
}
