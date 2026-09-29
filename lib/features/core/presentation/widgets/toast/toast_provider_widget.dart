import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_scope.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_notifier.dart';

final class const ToastProviderWidget({super.key, required final Widget child})
    extends StatefulWidget {
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
  static const _showDuration = Duration(milliseconds: 420);
  static const _hideDuration = Duration(milliseconds: 280);

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
        final navigationBarBackground = context.colors.surfaceDim;
        final iconBrightness = background.computeLuminance() > .5
            ? Brightness.dark
            : Brightness.light;
        final navigationBarIconBrightness =
            navigationBarBackground.computeLuminance() > .5
            ? Brightness.dark
            : Brightness.light;
        final animationsDisabled = MediaQuery.disableAnimationsOf(context);
        final animationDuration = animationsDisabled
            ? Duration.zero
            : toast == null
            ? _hideDuration
            : _showDuration;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarColor: navigationBarBackground,
            systemNavigationBarIconBrightness: navigationBarIconBrightness,
            statusBarBrightness: iconBrightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Stack(
            fit: .expand,
            children: [
              ColoredBox(color: context.colors.surface),
              child!,
              Positioned(
                top: 0.0,
                left: 0.0,
                right: 0.0,
                child: AnimatedSwitcher(
                  duration: animationsDisabled ? .zero : _showDuration,
                  reverseDuration: animationDuration,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0.0, -1.0),
                          end: .zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                            reverseCurve: Curves.easeInCubic,
                          ),
                        ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.0, 0.25),
                      ),
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
