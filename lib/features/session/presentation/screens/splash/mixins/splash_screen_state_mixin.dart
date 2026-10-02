import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/session/presentation/screens/splash/splash_screen.dart';

mixin SplashScreenStateMixin on State<SplashScreen> {
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    widget.command.execute.addListener(_handleSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.command.execute.value case final bool _) {
        _handleSession();
      } else {
        unawaited(_loadSession());
      }
    });
  }

  Future<void> _loadSession() async {
    try {
      await widget.command.loadSession();
    } catch (_) {
      if (!mounted || _redirected) return;
      _redirected = true;
      widget.onUnauthenticated(context);
    }
  }

  void _handleSession() {
    if (!mounted || _redirected) return;
    final session = widget.command.execute.value;
    if (session == null) return;

    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      session
          ? widget.onAuthenticated(context)
          : widget.onUnauthenticated(context);
    });
  }

  @override
  void dispose() {
    widget.command.execute.removeListener(_handleSession);
    super.dispose();
  }
}
