import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const PinFieldWidget({
  super.key,
  required final bool enabled,
  required final VoidCallback onSubmit,
  required final ValueChanged<String> onChanged,
  required final TextEditingController controller,
  required final String? failure,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextFieldWidget(
      controller: controller,
      autofocus: true,
      failure: failure,
      enabled: enabled,
      inputAction: .done,
      keyboardType: .number,
      label: 'Código de acesso',
      onChanged: _handleChanged,
      hint: 'Digite os 6 dígitos',
      onSubmitted: (_) => onSubmit(),
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
    );
  }

  void _handleChanged(String value) {
    onChanged(value);
    if (value.length == 6) onSubmit();
  }
}
