import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

final class const ExpenseCategoryFieldWidget({
  super.key,
  required final CategoryEnum value,
  required final VoidCallback? onTap,
  final bool enabled = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BounceWidget.withOnPress(
    onPress: onTap,
    child: TextFieldWidget(
      key: ValueKey(value),
      readOnly: true,
      absorbing: true,
      enabled: enabled,
      label: 'Categoria',
      initialValue: value.label,
      hint: 'Categoria do gasto',
    ),
  );
}
