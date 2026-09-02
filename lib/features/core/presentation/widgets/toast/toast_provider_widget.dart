import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_scope.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_notifier.dart';

final class ToastProviderWidget extends StatefulWidget {
  final Widget child;

  const ToastProviderWidget({super.key, required this.child});

  static ToastNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ToastScope>();
    if (scope == null) {
      throw FlutterError('ToastProvider is missing above this context.');
    }

    return scope.notifier;
  }

  @override
  State<ToastProviderWidget> createState() => _ToastProviderWidgetState();
}

final class _ToastProviderWidgetState extends State<ToastProviderWidget> {
  late final ToastNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ToastNotifier();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToastScope(
    notifier: _notifier,
    child: AnimatedBuilder(
      animation: _notifier,
      builder: (context, child) {
        final toast = _notifier.toast;
        final background = toast == null
            ? context.colors.surface
            : getToastPalette(context, toast.variant).background;
        final iconBrightness = background.computeLuminance() > .5
            ? Brightness.dark
            : Brightness.light;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            statusBarBrightness: iconBrightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Stack(
            fit: .expand,
            children: [
              child!,
              Positioned(
                top: 0.0,
                left: 0.0,
                right: 0.0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  reverseDuration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, -0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: toast == null
                      ? const SizedBox.shrink(key: ValueKey('empty-toast'))
                      : ToastWidget(
                          key: ValueKey(toast.id),
                          data: toast,
                          onDismiss: _notifier.hide,
                        ),
                ),
              ),
            ],
          ),
        );
      },
      child: widget.child,
    ),
  );
}
