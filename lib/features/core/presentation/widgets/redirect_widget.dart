import 'dart:async';

import 'package:material_ui/material_ui.dart';

final class RedirectWidget extends StatefulWidget {
  final Widget child;
  final Stream<void> events;
  final VoidCallback onAuthenticated;

  const RedirectWidget({
    super.key,
    required this.child,
    required this.events,
    required this.onAuthenticated,
  });

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
    _subscription = widget.events.listen((_) {
      if (!mounted) return;

      scheduleMicrotask(() {
        if (mounted) widget.onAuthenticated();
      });
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
