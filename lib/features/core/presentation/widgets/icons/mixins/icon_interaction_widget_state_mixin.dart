import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_interaction_widget.dart';

mixin IconInteractionWidgetStateMixin on State<IconInteractionWidget> {
  final ValueNotifier<int> animation = ValueNotifier<int>(0);

  void animate() {
    if (widget.enabled) animation.value++;
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      animate();
    }
    return .ignored;
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }
}
