import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/settings/domain/value_objects/support_pix.dart';
import 'package:cordato/features/settings/presentation/screens/support/support_screen.dart';

mixin SupportScreenStateMixin on State<SupportScreen> {
  Future<void> copyPix() async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: SupportPix.copyAndPaste),
      );
    } on PlatformException {
      if (mounted) {
        context.showToast(
          variant: .error,
          title: 'Tente novamente.',
          description: 'Não foi possível copiar o Pix',
        );
      }

      return;
    }

    if (mounted) {
      context.showToast(
        variant: .success,
        title: 'Pix copiado',
        description: 'Cole o código no aplicativo do seu banco.',
      );
    }
  }
}
