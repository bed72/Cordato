import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_date_picker_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/calculator/cents_calculator_widget.dart';

mixin ExpenseFormWidgetStateMixin on State<ExpenseFormWidget> {
  final descriptionController = TextEditingController();

  int cents = 0;
  String? dateFailure;
  String? centsFailure;
  String? descriptionFailure;
  bool _isPickerOpen = false;
  bool _keepFormOpenAfterCreation = false;
  DateTime occurredOn = DateUtils.dateOnly(.now());

  bool get isEditing => widget.id != null;

  bool get _isRunning => isEditing
      ? widget.updateCommand.execute.isRunning.value
      : widget.createCommand.execute.isRunning.value;

  bool get canSubmit {
    if (!widget.enabled || (isEditing && widget.initialExpense == null)) {
      return false;
    }
    if (!isEditing) return true;
    final initial = widget.initialExpense!;
    final hasChanges =
        cents != initial.cents.cents ||
        descriptionController.text.trim() != initial.description.trim() ||
        !DateUtils.isSameDay(occurredOn, initial.occurredOn);
    final validation = widget.validator(
      cents: cents,
      description: descriptionController.text,
      occurredOn: occurredOn,
    );
    return hasChanges &&
        validation.cents is Valid<int> &&
        validation.description is Valid<String> &&
        validation.occurredOn is Valid<DateTime?>;
  }

  @override
  void initState() {
    super.initState();
    descriptionController.text = widget.initialExpense?.description ?? '';
    cents = widget.initialExpense?.cents.cents ?? 0;
    occurredOn =
        widget.initialExpense?.occurredOn ?? DateUtils.dateOnly(.now());
    descriptionController.addListener(_refreshSubmit);
    widget.createCommand.execute.results.addListener(_handleCreation);
    widget.updateCommand.execute.results.addListener(_handleUpdate);
  }

  @override
  void didUpdateWidget(ExpenseFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.createCommand != widget.createCommand) {
      oldWidget.createCommand.execute.results.removeListener(_handleCreation);
      widget.createCommand.execute.results.addListener(_handleCreation);
    }
    if (oldWidget.updateCommand != widget.updateCommand) {
      oldWidget.updateCommand.execute.results.removeListener(_handleUpdate);
      widget.updateCommand.execute.results.addListener(_handleUpdate);
    }
  }

  @override
  void dispose() {
    widget.createCommand.execute.results.removeListener(_handleCreation);
    widget.updateCommand.execute.results.removeListener(_handleUpdate);
    descriptionController.removeListener(_refreshSubmit);
    descriptionController.dispose();
    super.dispose();
  }

  void _refreshSubmit() {
    if (mounted) setState(() {});
  }

  void onDescriptionChanged(String value) {
    if (descriptionFailure != null) setState(() => descriptionFailure = null);
  }

  Future<void> selectAmount() async {
    if (!widget.enabled || _isRunning || _isPickerOpen) return;
    _isPickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final value = await showBottomSheetWidget<int>(
        context: context,
        title: 'Valor do gasto',
        child: CentsCalculatorWidget(
          value: cents,
          formatter: widget.moneyFormatter,
        ),
      );

      if (!mounted) return;
      context.dismissKeyboard();
      if (value == null || _isRunning) return;
      setState(() {
        cents = value;
        centsFailure = null;
      });
    } finally {
      _isPickerOpen = false;
    }
  }

  Future<void> selectDate() async {
    if (!widget.enabled || _isRunning || _isPickerOpen) return;
    _isPickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final date = await showBottomSheetWidget<DateTime>(
        context: context,
        title: 'Data do gasto',
        child: ExpenseDatePickerWidget(date: occurredOn),
      );

      if (!mounted) return;
      context.dismissKeyboard();
      if (date == null || _isRunning) return;
      setState(() {
        occurredOn = date;
        dateFailure = null;
      });
    } finally {
      _isPickerOpen = false;
    }
  }

  void submitAndContinue() => submit(keepFormOpen: true);

  void submit({bool keepFormOpen = false}) {
    if (!mounted || !canSubmit || _isRunning || _isPickerOpen) return;
    context.dismissKeyboard();
    final validation = widget.validator(
      cents: cents,
      occurredOn: occurredOn,
      description: descriptionController.text,
    );

    setState(() {
      centsFailure = switch (validation.cents) {
        Invalid(:final message) => message,
        Valid() => null,
      };
      descriptionFailure = switch (validation.description) {
        Invalid(:final message) => message,
        Valid() => null,
      };
      dateFailure = switch (validation.occurredOn) {
        Invalid(:final message) => message,
        Valid() => null,
      };
    });

    if (validation case (
      cents: Valid(value: final validCents),
      description: Valid(value: final validDescription),
      occurredOn: Valid(value: final DateTime validDate),
    )) {
      if (isEditing) {
        final initial = widget.initialExpense!;
        widget.updateCommand.execute.run((
          id: widget.id!,
          cents: validCents == initial.cents.cents ? null : validCents,
          description: validDescription == initial.description.trim()
              ? null
              : validDescription,
          occurredOn: DateUtils.isSameDay(validDate, initial.occurredOn)
              ? null
              : validDate,
        ));
        return;
      }
      _keepFormOpenAfterCreation = keepFormOpen;
      widget.createCommand.execute.run((
        cents: validCents,
        occurredOn: validDate,
        description: validDescription,
      ));
    }
  }

  void _handleCreation() {
    final data = widget.createCommand.execute.results.value;
    if (!mounted ||
        isEditing ||
        !widget.enabled ||
        data.isRunning ||
        data.paramData == null) {
      return;
    }

    if (data.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao cadastrar gasto',
        description: 'Não foi possível cadastrar o gasto. Tente novamente.',
      );
      return;
    }

    if (data.data case Left(:final value)) {
      _showErrors(value);
      return;
    }

    if (data.data case Right()) {
      context.showToast(
        variant: .success,
        title: 'Gasto cadastrado',
        description: 'Seu gasto foi cadastrado com sucesso.',
      );

      _keepFormOpenAfterCreation
          ? _resetForm()
          : widget.onExpenseCreated(context);
    }
  }

  void _handleUpdate() {
    final data = widget.updateCommand.execute.results.value;
    if (!mounted ||
        !isEditing ||
        !widget.enabled ||
        data.isRunning ||
        data.paramData?.id != widget.id) {
      return;
    }
    if (data.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao atualizar gasto',
        description: 'Não foi possível atualizar o gasto. Tente novamente.',
      );
      return;
    }
    if (data.data case Left(:final value)) {
      _showErrors(value);
    } else if (data.data case Right(:final value)) {
      context.showToast(
        variant: .success,
        title: 'Gasto atualizado',
        description: 'Seu gasto foi atualizado com sucesso.',
      );
      widget.onExpenseUpdated(context, value);
    }
  }

  void _resetForm() {
    descriptionController.clear();

    setState(() {
      cents = 0;
      dateFailure = null;
      centsFailure = null;
      descriptionFailure = null;
      _keepFormOpenAfterCreation = false;
      occurredOn = DateUtils.dateOnly(.now());
    });
  }

  void _showErrors(ErrorsEntity errors) {
    final dateMessages = <String>[];
    final amountMessages = <String>[];
    final remaining = <ErrorEntity>[];
    final descriptionMessages = <String>[];

    for (final error in errors.errors) {
      final message = error.detail ?? error.title ?? 'Valor inválido.';

      switch (error.pointer) {
        case '/data/attributes/amount':
          amountMessages.add(message);
        case '/data/attributes/description':
          descriptionMessages.add(message);
        case '/data/attributes/occurred_on':
          dateMessages.add(message);
        default:
          remaining.add(error);
      }
    }

    setState(() {
      dateFailure = dateMessages.isEmpty ? null : dateMessages.join('\n');
      centsFailure = amountMessages.isEmpty ? null : amountMessages.join('\n');
      descriptionFailure = descriptionMessages.isEmpty
          ? null
          : descriptionMessages.join('\n');
    });

    if (remaining.isNotEmpty) {
      context.showToast(
        variant: .error,
        title:
            remaining.first.title ??
            (isEditing ? 'Erro ao atualizar gasto' : 'Erro ao cadastrar gasto'),
        description: remaining
            .map((error) => error.detail ?? error.title ?? 'Tente novamente.')
            .join('\n'),
      );
    }
  }
}
