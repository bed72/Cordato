import 'dart:async';

import 'package:material_ui/material_ui.dart';

final class const RedirectWidget({
  super.key,
  required final Widget child,
  required final Stream<void> events,
  required final VoidCallback onAuthenticated,
  required final ValueChanged<BuildContext> onAuthenticationFailure,
}) extends StatefulWidget {
  @override
  State<RedirectWidget> createState() => _RedirectWidgetState();
}

final class _RedirectWidgetState extends State<RedirectWidget> {
  late StreamSubscription<void> _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(RedirectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.events, widget.events)) {
      return;
    }

    unawaited(_subscription.cancel());
    _subscribe();
  }

  void _subscribe() {
    _subscription = widget.events.listen(
      (_) => _schedule(widget.onAuthenticated),
      onError: _handleAuthenticationFailure,
    );
  }

  void _handleAuthenticationFailure(Object _, StackTrace _) =>
      _schedule(() => widget.onAuthenticationFailure(context));

  void _schedule(VoidCallback callback) {
    if (!mounted) return;

    scheduleMicrotask(() {
      if (mounted) callback();
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
