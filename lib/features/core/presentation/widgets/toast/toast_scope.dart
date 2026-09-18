import 'package:cordato/features/core/presentation/widgets/toast/toast_notifier.dart';
import 'package:material_ui/material_ui.dart';

final class const ToastScope({
  super.key,
  required final ToastNotifier notifier,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(ToastScope oldWidget) =>
      notifier != oldWidget.notifier;
}
