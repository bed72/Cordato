import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/budget/presentation/widgets/budget_form_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/calculator/budget_amount_calculator_widget.dart';

mixin BudgetFormWidgetStateMixin on State<BudgetFormWidget> {
  int amountInCents = 0;

  Future<void> selectAmount() async {
    final cents = await showBottomSheetWidget<int>(
      context: context,
      title: 'Qual o valor?',
      subtitle: 'Informe o valor do orçamento.',
      child: BudgetAmountCalculatorWidget(
        value: amountInCents,
        formatter: widget.formatter,
      ),
    );

    if (!mounted || cents == null) return;

    setState(() => amountInCents = cents);
  }
}
