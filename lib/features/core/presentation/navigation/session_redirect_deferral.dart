final class SessionRedirectDeferral({
  required final void Function() onReleased,
}) {
  final Map<Object, String> _holds = {};

  bool isDeferredFor(String path) => _holds.containsValue(path);

  void Function() hold(String path) {
    final key = Object();
    _holds[key] = path;
    return () {
      if (_holds.remove(key) != null) onReleased();
    };
  }
}
