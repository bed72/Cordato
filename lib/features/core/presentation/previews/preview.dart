import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';

const cordatoPhonePreviewSize = Size(390.0, 844.0);

Widget cordatoPreviewWrapper(Widget child) =>
    _LocaleReadyWidget(child: MaterialPreviewWidget(child: child));

final class const CordatoPreview({
  super.name,
  super.size,
  super.group,
  super.brightness,
}) extends Preview {
  this : super(wrapper: cordatoPreviewWrapper);
}

class const _LocaleReadyWidget({required final Widget child})
    extends StatefulWidget {
  @override
  State<_LocaleReadyWidget> createState() => _LocaleReadyWidgetState();
}

class _LocaleReadyWidgetState extends State<_LocaleReadyWidget> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR').then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.shrink();
}
