import 'dart:async';

import 'package:material_ui/material_ui.dart';

class LoopAnimation extends StatefulWidget {
  final List<Widget> items;
  final Duration pauseDuration;
  final Duration animationDuration;

  const LoopAnimation({
    super.key,
    required this.items,
    this.pauseDuration = const Duration(milliseconds: 1400),
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<LoopAnimation> createState() => _LoopAnimationState();
}

class _LoopAnimationState extends State<LoopAnimation>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _forward = true;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addStatusListener(_onStatusChanged);

    _startLoop();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _forward = false;
      _scheduleNext();

      return;
    }

    if (status == AnimationStatus.dismissed) {
      _forward = true;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(widget.pauseDuration, () {
      if (mounted) {
        _forward ? _controller.forward() : _controller.reverse();
      }
    });
  }

  void _startLoop() {
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.items.first;
    final second = widget.items.length > 1 ? widget.items[1] : first;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = Curves.easeInOut.transform(_controller.value);
        final offsetY = value * -1.0;

        final opacityBottom = value;
        final opacityTop = 1.0 - value;

        return ClipRect(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Opacity(
                opacity: opacityTop,
                child: FractionalTranslation(
                  translation: Offset(0, offsetY),
                  child: first,
                ),
              ),
              const SizedBox(height: 1.0),
              Opacity(
                opacity: opacityBottom,
                child: FractionalTranslation(
                  translation: Offset(0, offsetY + 1.0),
                  child: second,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
