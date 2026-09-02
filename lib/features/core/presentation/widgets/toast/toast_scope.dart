import 'package:cordato/features/core/presentation/widgets/toast/toast_notifier.dart';
import 'package:material_ui/material_ui.dart';

final class ToastScope extends InheritedWidget {
  final ToastNotifier notifier;

  const ToastScope({super.key, required this.notifier, required super.child});

  @override
  bool updateShouldNotify(ToastScope oldWidget) =>
      notifier != oldWidget.notifier;
}
