import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/states/expense_form_state.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_date_picker_widget.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';
import 'package:cordato/features/core/presentation/widgets/calculator/amount_calculator_widget.dart';

mixin ExpenseFormWidgetStateMixin on State<ExpenseFormWidget> {
  ExpenseFormState formState = ExpenseFormState(
    date: DateUtils.dateOnly(DateTime.now()),
  );
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
      subtitle: 'Informe o valor do gasto.',
      child: AmountCalculatorWidget(
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

  Future<void> selectDate() async {
    final initialDate = formState.date ?? DateUtils.dateOnly(DateTime.now());
    final date = await showBottomSheetWidget<DateTime>(
      context: context,
      title: 'Qual a data?',
      subtitle: 'Informe a data do gasto.',
      child: ExpenseDatePickerWidget(date: initialDate),
    );

    if (!mounted || date == null) return;
    setState(
      () => formState = formState.copyWith(date: date, clearDateFailure: true),
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

    final date = validation.state.date;
    if (date == null) return;

    final expense = ExpenseEntity.create(
      date: date,
      amount: validation.state.value,
      description: validation.state.description,
    );

    if (expense != null) widget.command.create.run(expense);
  }

  void _handleCreate() {
    final data = widget.command.create.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

    if (data.hasError) {
      context.showToast(
        variant: .error,
        description: data.error.toString(),
        title: 'Não foi possível cadastrar o gasto',
      );
      return;
    }

    if (data.isSuccess) {
      context.showToast(
        variant: .success,
        title: 'Gasto cadastrado',
        description: 'Seu gasto foi salvo com sucesso.',
      );

      widget.onExpenseCreated(context);
    }
  }
}
