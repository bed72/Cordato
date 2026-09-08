import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/presentation/states/budget_form_state.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_form_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/budget_date_range_picker_widget.dart';
import 'package:cordato/features/budget/presentation/widgets/calculator/budget_amount_calculator_widget.dart';

mixin BudgetFormWidgetStateMixin on State<BudgetFormWidget> {
  BudgetFormState formState = const BudgetFormState();
  final descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.command.create.results.addListener(_handleCreate);
  }

  @override
  void dispose() {
    widget.command.create.results.removeListener(_handleCreate);
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> selectAmount() async {
    final cents = await showBottomSheetWidget<int>(
      context: context,
      title: 'Qual o valor?',
      subtitle: 'Informe o valor do orçamento.',
      child: BudgetAmountCalculatorWidget(
        value: formState.value,
        formatter: widget.formatter,
      ),
    );

    if (!mounted || cents == null) return;

    setState(
      () =>
          formState = formState.copyWith(value: cents, clearValueFailure: true),
    );
  }

  Future<void> selectPeriod() async {
    final selectedPeriod = await showBottomSheetWidget<DateTimeRange>(
      context: context,
      title: 'Período',
      subtitle: 'Selecione o período do orçamento.',
      child: BudgetDateRangePickerWidget(range: formState.period),
    );

    if (!mounted || selectedPeriod == null) return;

    setState(
      () => formState = formState.copyWith(
        period: selectedPeriod,
        clearPeriodFailure: true,
      ),
    );
  }

  void updateDescription(String description) => setState(
    () => formState = formState.copyWith(
      description: description,
      clearDescriptionFailure: true,
    ),
  );

  void submit() {
    context.dismissKeyboard();
    final validation = widget.validator(formState);

    setState(() => formState = validation.state);
    if (!validation.isValid) return;

    final period = validation.state.period;
    if (period == null) return;

    final budget = BudgetEntity.create(
      endDate: period.end,
      startDate: period.start,
      amount: validation.state.value,
      description: validation.state.description,
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
        title: 'Não foi possível cadastrar o orçamento',
      );

      return;
    }

    if (data.isSuccess) {
      context.showToast(
        variant: .success,
        title: 'Orçamento cadastrado',
        description: 'Seu orçamento foi salvo com sucesso.',
      );

      widget.onBudgetCreated(context);
    }
  }
}
