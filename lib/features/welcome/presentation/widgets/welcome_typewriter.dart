import 'dart:async';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:material_ui/material_ui.dart';

final class WelcomeTypewriterWidget extends StatefulWidget {
  final Color color;
  final List<String> phrases;

  const WelcomeTypewriterWidget({
    super.key,
    required this.color,
    required this.phrases,
  }) : assert(phrases.length > 0);

  @override
  State<WelcomeTypewriterWidget> createState() =>
      _WelcomeTypewriterWidgetState();
}

final class _WelcomeTypewriterWidgetState
    extends State<WelcomeTypewriterWidget> {
  Timer? _timer;
  String _typedPhrase = '';
  int _cursorBlinkCount = 0;
  int _activePhraseIndex = 0;
  bool _isCursorVisible = true;
  bool _isErasingPhrase = false;
  bool _isBlinkingCursor = false;

  String get _activePhrase => widget.phrases[_activePhraseIndex];

  @override
  void initState() {
    super.initState();
    _schedule(const Duration(milliseconds: 70));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _updateTypewriter);
  }

  void _updateTypewriter() {
    if (!mounted) return;

    if (_isBlinkingCursor) {
      setState(() {
        _isCursorVisible = !_isCursorVisible;
        if (_isCursorVisible) _cursorBlinkCount++;
      });

      if (_cursorBlinkCount == 4) {
        setState(() {
          _isBlinkingCursor = false;
          _isErasingPhrase = true;
        });
        _schedule(const Duration(milliseconds: 45));
      } else {
        _schedule(const Duration(milliseconds: 250));
      }
      return;
    }

    if (_isErasingPhrase && _typedPhrase.isNotEmpty) {
      setState(() {
        _typedPhrase = _typedPhrase.substring(0, _typedPhrase.length - 1);
      });
      _schedule(const Duration(milliseconds: 45));
      return;
    }

    if (_isErasingPhrase) {
      setState(() {
        _isErasingPhrase = false;
        _activePhraseIndex = (_activePhraseIndex + 1) % widget.phrases.length;
        _isCursorVisible = true;
      });
      _schedule(const Duration(milliseconds: 70));
      return;
    }

    if (_typedPhrase.length < _activePhrase.length) {
      setState(() {
        _typedPhrase = _activePhrase.substring(0, _typedPhrase.length + 1);
      });
      _schedule(const Duration(milliseconds: 70));
      return;
    }

    setState(() {
      _isBlinkingCursor = true;
      _cursorBlinkCount = 0;
      _isCursorVisible = true;
    });
    _schedule(const Duration(milliseconds: 1600));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: _typedPhrase,
    child: ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _typedPhrase),
            TextSpan(
              text: '|',
              style: TextStyle(
                color: _isCursorVisible ? widget.color : Colors.transparent,
              ),
            ),
          ],
        ),
        textAlign: .center,
        style: context.typography.headlineSmall?.copyWith(
          fontWeight: .w600,
          color: widget.color,
        ),
      ),
    ),
  );
}
