import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class const AmountFieldWidget({
  super.key,
  required final int value,
  required final VoidCallback? onTap,
  required final IMoneyFormatter formatter,
  final String? failure,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BounceWidget.withOnPress(
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
}
