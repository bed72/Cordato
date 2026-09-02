import 'package:material_ui/material_ui.dart';
import 'package:flutter/physics.dart';

const _upScale = 1.0;
const _downScale = 0.96;
const _springMass = 0.5;
const _pressInDamping = 16.0;
const _pressInStiffness = 320.0;
const _pressOutDamping = 14.0;
const _pressOutStiffness = 280.0;

abstract base class BounceWidget extends StatefulWidget {
  const BounceWidget({super.key, required this.child});

  final Widget child;

  factory BounceWidget.withOnPress({
    Key? key,
    required Widget child,
    required VoidCallback? onPress,
  }) => _BounceWithOnPressWidget(key: key, onPress: onPress, child: child);

  factory BounceWidget.withoutOnPress({Key? key, required Widget child}) =>
      _BounceWithoutPressWidget(key: key, child: child);
}

final class _BounceWithOnPressWidget extends BounceWidget {
  const _BounceWithOnPressWidget({
    super.key,
    required super.child,
    required this.onPress,
  });

  final VoidCallback? onPress;

  @override
  State<_BounceWithOnPressWidget> createState() =>
      _BounceWithOnPressWidgetState();
}

final class _BounceWithOnPressWidgetState
    extends State<_BounceWithOnPressWidget> {
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onPress == null
        ? null
        : () async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            if (mounted) widget.onPress?.call();
          },
    child: _BounceWithoutPressWidget(child: widget.child),
  );
}

final class _BounceWithoutPressWidget extends BounceWidget {
  const _BounceWithoutPressWidget({super.key, required super.child});

  @override
  State<_BounceWithoutPressWidget> createState() =>
      _BounceWithoutPressWidgetState();
}

final class _BounceWithoutPressWidgetState
    extends State<_BounceWithoutPressWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController =
      AnimationController.unbounded(vsync: this, value: _upScale);

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) => _animateTo(
    target: _downScale,
    damping: _pressInDamping,
    stiffness: _pressInStiffness,
  );

  void _onPointerUp(PointerUpEvent _) => _animateTo(
    target: _upScale,
    damping: _pressOutDamping,
    stiffness: _pressOutStiffness,
  );

  void _onPointerCancel(PointerCancelEvent _) => _animateTo(
    target: _upScale,
    damping: _pressOutDamping,
    stiffness: _pressOutStiffness,
  );

  void _animateTo({
    required double target,
    required double damping,
    required double stiffness,
  }) {
    _scaleController.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: _springMass,
          damping: damping,
          stiffness: stiffness,
        ),
        _scaleController.value,
        target,
        _scaleController.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerUp: _onPointerUp,
    onPointerCancel: _onPointerCancel,
    child: AnimatedBuilder(
      animation: _scaleController,
      child: widget.child,
      builder: (_, child) =>
          Transform.scale(scale: _scaleController.value, child: child),
    ),
  );
}
