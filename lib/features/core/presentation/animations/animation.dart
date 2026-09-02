import 'package:flutter/widgets.dart';

const _duration = Duration(milliseconds: 300);

class SwitcherAnimation extends StatelessWidget {
  final Widget child;

  const SwitcherAnimation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: child,
    );
  }
}

class SwitcherSizeAnimation extends StatelessWidget {
  final Widget child;

  const SwitcherSizeAnimation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        alignment: .topCenter,
        sizeFactor: animation,
        child: child,
      ),
      child: child,
    );
  }
}

class SlideAnimation extends StatelessWidget {
  final Widget child;
  final bool condition;

  const SlideAnimation({
    super.key,
    required this.child,
    required this.condition,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: _duration,
      curve: Curves.decelerate,
      offset: condition ? const Offset(0, 1) : .zero,
      child: AnimatedOpacity(
        duration: _duration,
        opacity: condition ? 0 : 1,
        child: child,
      ),
    );
  }
}
