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
  static const _showDuration = Duration(milliseconds: 420);
  static const _hideDuration = Duration(milliseconds: 280);

  late final ToastNotifier _notifier;
  final _toastMeasureKey = GlobalKey();

  double _toastHeight = 0.0;

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

  void _updateToastHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final height = _toastMeasureKey.currentContext?.size?.height ?? 0.0;
      if (height <= 0.0 || (height - _toastHeight).abs() < 0.5) return;

      setState(() => _toastHeight = height);
    });
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
        final animationCurve = toast == null
            ? Curves.easeInCubic
            : Curves.easeOutBack;
        final screenBorderRadius = toast == null
            ? BorderRadius.zero
            : BorderRadius.only(
                topLeft: context.radius.cornerRadius300.topLeft,
                topRight: context.radius.cornerRadius300.topRight,
              );

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final revealOffset = screenHeight <= 0.0
                  ? 0.0
                  : _toastHeight / screenHeight;

              return Stack(
                fit: .expand,
                clipBehavior: .none,
                children: [
                  ColoredBox(color: background),
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    right: 0.0,
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        _updateToastHeight();
                        return true;
                      },
                      child: SizeChangedLayoutNotifier(
                        key: _toastMeasureKey,
                        child: AnimatedSwitcher(
                          duration: animationsDisabled
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          reverseDuration: animationDuration,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.0, 0.25),
                                ),
                                child: child,
                              ),
                          child: toast == null
                              ? const SizedBox.shrink(
                                  key: ValueKey('empty-toast'),
                                )
                              : ToastWidget(
                                  key: ValueKey(toast.id),
                                  data: toast,
                                  onDismiss: _notifier.hide,
                                ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedSlide(
                    offset: Offset(0.0, toast == null ? 0.0 : revealOffset),
                    duration: animationDuration,
                    curve: animationCurve,
                    child: AnimatedContainer(
                      duration: animationDuration,
                      curve: animationCurve,
                      clipBehavior: .antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: screenBorderRadius,
                        boxShadow: toast == null
                            ? const []
                            : [
                                BoxShadow(
                                  blurRadius: 20.0,
                                  spreadRadius: 1.0,
                                  offset: const Offset(0.0, -4.0),
                                  color: context.colors.shadow.withValues(
                                    alpha: context.isDark ? 0.4 : 0.2,
                                  ),
                                ),
                              ],
                      ),
                      child: child!,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      child: widget.child,
    ),
  );
}
