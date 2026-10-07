import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_date_picker_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/create_expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/calculator/amount_calculator_widget.dart';

mixin CreateExpenseFormWidgetStateMixin on State<CreateExpenseFormWidget> {
  final descriptionController = TextEditingController();

  int cents = 0;
  String? dateFailure;
  String? centsFailure;
  String? descriptionFailure;
  bool _isPickerOpen = false;
  bool _keepFormOpenAfterCreation = false;
  DateTime occurredOn = DateUtils.dateOnly(.now());

  bool get _isRunning => widget.command.execute.isRunning.value;

  @override
  void initState() {
    super.initState();

    widget.command.execute.results.addListener(_handleCreation);
  }

  @override
  void didUpdateWidget(CreateExpenseFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.command != widget.command) {
      oldWidget.command.execute.results.removeListener(_handleCreation);
      widget.command.execute.results.addListener(_handleCreation);
    }
  }

  @override
  void dispose() {
    widget.command.execute.results.removeListener(_handleCreation);
    descriptionController.dispose();
    super.dispose();
  }

  void onDescriptionChanged(String value) {
    if (descriptionFailure != null) setState(() => descriptionFailure = null);
  }

  Future<void> selectAmount() async {
    if (_isRunning || _isPickerOpen) return;
    _isPickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final value = await showBottomSheetWidget<int>(
        context: context,
        title: 'Valor do gasto',
        child: AmountCalculatorWidget(
          value: cents,
          formatter: widget.formatter,
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
    if (_isRunning || _isPickerOpen) return;
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
    if (!mounted || _isRunning || _isPickerOpen) return;
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
      _keepFormOpenAfterCreation = keepFormOpen;
      widget.command.execute.run(
        CreateExpenseInput(
          cents: validCents,
          occurredOn: validDate,
          description: validDescription,
        ),
      );
    }
  }

  void _handleCreation() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

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
        title: remaining.first.title ?? 'Erro ao cadastrar gasto',
        description: remaining
            .map((error) => error.detail ?? error.title ?? 'Tente novamente.')
            .join('\n'),
      );
    }
  }
}
