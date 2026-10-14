import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/root/presentation/screens/app/app_screen.dart';

mixin AppScreenStateMixin on State<AppScreen> {
  bool _redirected = false;
  int _dependenciesVersion = 0;

  @override
  void initState() {
    super.initState();

    widget.command.execute.addListener(_handleSession);
    _scheduleSessionLoad();
  }

  @override
  void didUpdateWidget(covariant AppScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command == widget.command) return;
    oldWidget.command.execute.removeListener(_handleSession);
    _dependenciesVersion++;
    _redirected = false;
    widget.command.execute.addListener(_handleSession);
    _scheduleSessionLoad();
  }

  void _scheduleSessionLoad() {
    final version = _dependenciesVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _dependenciesVersion) return;

      if (widget.command.execute.value case final bool _) {
        _handleSession();
      } else {
        unawaited(_loadSession());
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _loadSession() async {
    final version = _dependenciesVersion;
    final command = widget.command;
    try {
      await command.loadSession();
    } catch (_) {
      if (!mounted ||
          version != _dependenciesVersion ||
          widget.command != command ||
          _redirected) {
        return;
      }
      _redirected = true;
      widget.onUnauthenticated(context);
    }
  }

  void _handleSession() {
    if (!mounted || _redirected) return;
    final session = widget.command.execute.value;
    if (session == null) return;

    final version = _dependenciesVersion;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _dependenciesVersion) return;

      final currentSession = widget.command.execute.value;
      if (currentSession == null) return;
      currentSession
          ? widget.onAuthenticated(context)
          : widget.onUnauthenticated(context);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _dependenciesVersion++;
    widget.command.execute.removeListener(_handleSession);
    super.dispose();
  }
}
