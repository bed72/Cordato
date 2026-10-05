import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/date_time_range_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const DateFieldWidget({
  super.key,
  required final String hint,
  required final String label,
  required final VoidCallback? onTap,
  required final DateTimeRange? value,
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
        initialValue: value?.format(),
      ),
    );
  }
}
