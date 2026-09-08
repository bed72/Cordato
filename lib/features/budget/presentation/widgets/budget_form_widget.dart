import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_header_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/calculator/budget_amount_calculator_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/fields/budget_amount_field_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/fields/budget_date_field_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/fields/budget_description_field_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

final class BudgetFormWidget extends StatefulWidget {
  final IMoneyFormatter formatter;

  const BudgetFormWidget({super.key, required this.formatter});

  @override
  State<BudgetFormWidget> createState() => _BudgetFormWidgetState();
}

final class _BudgetFormWidgetState extends State<BudgetFormWidget> {
  int _amountInCents = 0;

  Future<void> _selectAmount() async {
    final amountInCents = await showBottomSheetWidget<int>(
      context: context,
      title: 'Qual o valor?',
      subtitle: 'Informe o valor do orçamento.',
      child: BudgetAmountCalculatorWidget(
        value: _amountInCents,
        formatter: widget.formatter,
      ),
    );

    if (!mounted || amountInCents == null) return;
    setState(() => _amountInCents = amountInCents);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const .symmetric(vertical: 24.0),
            child: Column(
              spacing: 16.0,
              crossAxisAlignment: .stretch,
              children: [
                const BudgetHeaderWidget(),
                BudgetAmountFieldWidget(
                  formatter: widget.formatter,
                  value: _amountInCents,
                  onTap: _selectAmount,
                ),
                const BudgetDescriptionFieldWidget(),
                const BudgetDateFieldWidget(),
              ],
            ),
          ),
        ),
        const ElevatedButtonWidget(label: 'Cadastrar', onTap: null),
      ],
    ),
  );
}
