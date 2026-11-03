import 'package:material_ui/material_ui.dart';

final class const IconAnimationScopeWidget({
  super.key,
  required super.notifier,
  required final bool enabled,
  required super.child,
}) extends InheritedNotifier<ValueNotifier<int>> {
  static IconAnimationScopeWidget? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IconAnimationScopeWidget>();

  @override
  bool updateShouldNotify(IconAnimationScopeWidget oldWidget) =>
      enabled != oldWidget.enabled || super.updateShouldNotify(oldWidget);
}
