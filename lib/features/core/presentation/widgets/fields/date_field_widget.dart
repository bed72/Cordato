import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const DateFieldWidget({
  super.key,
  required final String hint,
  required final String label,
  required final VoidCallback? onTap,
  required final DateTimeRange? value,
  required final IDateFormatter formatter,
  final String? failure,
  final bool enabled = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BounceWidget.withOnPress(
      onPress: onTap,
      child: TextFieldWidget(
        key: ValueKey(value),
        hint: hint,
        label: label,
        readOnly: true,
        absorbing: true,
        enabled: enabled,
        failure: failure,
        initialValue: value == null
            ? null
            : formatter.formatShortPeriod(value!.start, value!.end),
      ),
    );
  }
}
