import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_category_item_widget.dart';

final class const ExpenseCategoryPickerWidget({
  super.key,
  required final ExpenseCategoryEnum value,
}) extends StatefulWidget {
  @override
  State<ExpenseCategoryPickerWidget> createState() =>
      _ExpenseCategoryPickerWidgetState();
}

final class _ExpenseCategoryPickerWidgetState
    extends State<ExpenseCategoryPickerWidget> {
  late ExpenseCategoryEnum _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    left: false,
    right: false,
    child: Column(
      mainAxisSize: .min,
      spacing: 16.0,
      children: [
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const .only(top: 16.0),
            itemCount: ExpenseCategoryExtension.orderedValues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8.0),
            itemBuilder: (_, index) {
              final category = ExpenseCategoryExtension.orderedValues[index];
              return ExpenseCategoryItemWidget(
                category: category,
                selected: _selected == category,
                onPressed: () => setState(() => _selected = category),
              );
            },
          ),
        ),
        SizedBox(
          width: .infinity,
          child: ElevatedButtonWidget(
            label: 'Confirmar',
            onTap: () => Navigator.pop<ExpenseCategoryEnum>(context, _selected),
          ),
        ),
      ],
    ),
  );
}
