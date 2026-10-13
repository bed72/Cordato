import 'package:flutter/widgets.dart';

const _duration = Duration(milliseconds: 300);

class const SwitcherAnimation({super.key, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        key: ObjectKey(animation),
        opacity: animation,
        child: child,
      ),
      child: child,
    );
  }
}

class const SwitcherSizeAnimation({super.key, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        key: ObjectKey(animation),
        alignment: .topCenter,
        sizeFactor: animation,
        child: child,
      ),
      child: child,
    );
  }
}

class const SlideAnimation({
  super.key,
  required final Widget child,
  required final bool condition,
}) extends StatelessWidget {
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
