import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class BudgetAmountFieldWidget extends StatelessWidget {
  final int value;
  final IMoneyFormatter formatter;
  final VoidCallback? onTap;
  final String? failure;

  const BudgetAmountFieldWidget({
    super.key,
    required this.value,
    required this.onTap,
    required this.formatter,
    this.failure,
  });

  @override
  Widget build(BuildContext context) => BounceWidget.withOnPress(
    onPress: onTap,
    child: TextFieldWidget(
      key: ValueKey(value),
      label: 'Valor',
      readOnly: true,
      absorbing: true,
      failure: failure,
      hint: 'Ex: R\$ 1.000,00',
      initialValue: value > 0 ? formatter.formatCents(value) : null,
    ),
  );
}
