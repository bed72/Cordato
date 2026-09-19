import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';
import 'package:cordato/features/core/presentation/widgets/calculator/amount_calculator_widget.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';

import 'package:cordato/features/budget/presentation/states/budget_form_state.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_form_widget.dart';
import 'package:cordato/features/budget/presentation/enums/budget_period_option_enum.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_date_range_picker_widget.dart';

mixin BudgetFormWidgetStateMixin on State<BudgetFormWidget> {
  BudgetFormState form = .initial(.now());

  @override
  void initState() {
    super.initState();
    widget.command.create.results.addListener(_handleCreate);
  }

  @override
  void dispose() {
    widget.command.create.results.removeListener(_handleCreate);
    super.dispose();
  }

  Future<void> selectAmount() async {
    final cents = await showBottomSheetWidget<int>(
      context: context,
      title: 'Qual o valor?',
      subtitle: 'Informe quanto você quer gastar.',
      child: AmountCalculatorWidget(
        value: form.value,
        formatter: widget.formatter,
      ),
    );

    if (!mounted || cents == null) return;

    setState(() => form = form.copyWith(value: cents, clearValueFailure: true));
  }

  Future<void> selectPeriod(BudgetPeriodOptionEnum option) async {
    if (option != .custom) {
      final period = option.periodStartingAt(.now());
      if (period == null) return;

      setState(
        () => form = form.copyWith(
          period: period,
          periodOption: option,
          clearPeriodFailure: true,
        ),
      );
      return;
    }

    final selectedPeriod = await showBottomSheetWidget<DateTimeRange>(
      context: context,
      title: 'Período',
      subtitle: 'Selecione as datas deste período.',
      child: BudgetDateRangePickerWidget(range: form.period),
    );

    if (!mounted || selectedPeriod == null) return;

    setState(
      () => form = form.copyWith(
        period: selectedPeriod,
        periodOption: .custom,
        clearPeriodFailure: true,
      ),
    );
  }

  void updateRecurrence(bool isRecurring) =>
      setState(() => form = form.copyWith(isRecurring: isRecurring));

  void submit() {
    context.dismissKeyboard();
    final validation = widget.validator(form);

    setState(() => form = validation.state);
    if (!validation.isValid) return;

    final period = validation.state.period;
    if (period == null) return;

    final budget = BudgetEntity.create(
      endDate: period.end,
      startDate: period.start,
      amount: validation.state.value,
    );

    if (budget != null) widget.command.create.run(budget);
  }

  void _handleCreate() {
    final data = widget.command.create.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

    if (data.hasError) {
      context.showToast(
        variant: .error,
        description: data.error.toString(),
        title: 'Não foi possível cadastrar o valor',
      );

      return;
    }

    if (data.isSuccess) {
      context.showToast(
        variant: .success,
        title: 'Valor cadastrado',
        description: 'Seu valor foi salvo com sucesso.',
      );

      widget.onBudgetCreated(context);
    }
  }
}
