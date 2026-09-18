import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const DateFieldWidget({
  super.key,
  required final String label,
  required final String hint,
  required final DateTimeRange? value,
  required final VoidCallback? onTap,
  final String? failure,
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
        failure: failure,
        initialValue: value == null ? null : _format(value!),
      ),
    );
  }

  String _format(DateTimeRange range) {
    final formatter = DateFormat('dd/MM/yyyy');
    final end = formatter.format(range.end);
    final start = formatter.format(range.start);

    return start == end ? start : '$start até $end';
  }
}
