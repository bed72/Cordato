import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';

final class ToastNotifier extends ChangeNotifier {
  Timer? _timer;
  ToastData? _toast;

  int _nextId = 0;

  ToastData? get toast => _toast;

  void show({
    required String title,
    Duration? duration,
    String? description,
    ToastAction? action,
    ToastVariant variant = .info,
  }) {
    _timer?.cancel();
    _nextId++;
    _toast = ToastData(
      id: _nextId,
      title: title,
      action: action,
      variant: variant,
      duration: duration,
      description: description,
    );
    notifyListeners();

    final hideAfter = duration ?? Duration(seconds: 6);
    if (hideAfter != Duration.zero) {
      _timer = Timer(hideAfter, hide);
    }
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (_toast == null) return;
    _toast = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
