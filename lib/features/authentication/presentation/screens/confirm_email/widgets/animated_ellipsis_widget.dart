import 'package:material_ui/material_ui.dart';

const _jumpHeight = 4.0;
const _jumpDuration = Duration(milliseconds: 360);
const _cycleDuration = Duration(milliseconds: 920);
const _staggerDuration = Duration(milliseconds: 280);

final class const AnimatedEllipsisWidget({super.key, final TextStyle? style})
    extends StatefulWidget {
  @override
  State<AnimatedEllipsisWidget> createState() => _AnimatedEllipsisWidgetState();
}

final class _AnimatedEllipsisWidgetState extends State<AnimatedEllipsisWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _cycleDuration, vsync: this)
      ..repeat();
  }

  double _offsetForDot(int index) {
    final start = _staggerDuration.inMilliseconds * index;
    final end = start + _jumpDuration.inMilliseconds;
    final progress = Interval(
      start / _cycleDuration.inMilliseconds,
      end / _cycleDuration.inMilliseconds,
    ).transform(_controller.value);

    final jumpProgress = progress <= 0.5
        ? Curves.easeOutCubic.transform(progress * 2.0)
        : Curves.easeInCubic.transform((1.0 - progress) * 2.0);

    return -_jumpHeight * jumpProgress;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: .min,
        textBaseline: .alphabetic,
        crossAxisAlignment: .baseline,
        children: .generate(
          3,
          (index) => Transform.translate(
            offset: Offset(0.0, _offsetForDot(index)),
            key: ValueKey('animated-ellipsis-dot-$index'),
            child: Text('.', style: widget.style),
          ),
        ),
      ),
    );
  }
}
