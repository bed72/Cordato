import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class BudgetDateFieldWidget extends StatelessWidget {
  final String? failure;
  final VoidCallback? onTap;
  final DateTimeRange? value;

  const BudgetDateFieldWidget({
    super.key,
    required this.value,
    required this.onTap,
    this.failure,
  });

  @override
  Widget build(BuildContext context) => BounceWidget.withOnPress(
    onPress: onTap,
    child: TextFieldWidget(
      key: ValueKey(value),
      readOnly: true,
      absorbing: true,
      label: 'Período',
      failure: failure,
      hint: 'Data de início e término',
      initialValue: value == null ? null : _formatPeriod(value!),
    ),
  );

  String _formatPeriod(DateTimeRange range) {
    final formatter = DateFormat('dd/MM/yyyy');
    final end = formatter.format(range.end);
    final start = formatter.format(range.start);

    return start == end ? start : '$start até $end';
  }
}
