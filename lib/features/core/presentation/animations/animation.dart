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
