import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/formatters/expense_error_message_formatter.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_date_picker_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_category_picker_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/calculator/cents_calculator_widget.dart';

mixin ExpenseFormWidgetStateMixin on State<ExpenseFormWidget> {
  final descriptionController = TextEditingController();

  int cents = 0;
  ExpenseCategoryEnum category = .other;
  bool hasManualAmount = false;
  ExpenseSuggestionEntity? _selectedSuggestion;

  int? get suggestedAmountAction =>
      hasManualAmount ? _selectedSuggestion?.cents : null;
  String? dateFailure;
  String? centsFailure;
  String? descriptionFailure;
  bool _isPickerOpen = false;
  DateTime occurredOn = DateUtils.dateOnly(.now());

  bool get isEditing => widget.id != null;

  bool get _isRunning => widget.expenseBloc.state.isSubmitting;

  bool get canSubmit {
    if (!widget.enabled ||
        !widget.expenseBloc.state.canSubmit ||
        (isEditing && widget.initialExpense == null)) {
      return false;
    }
    if (!isEditing) {
      return true;
    }

    final initial = widget.initialExpense!;
    final hasChanges =
        cents != initial.cents.cents ||
        category != initial.category ||
        descriptionController.text.trim() != initial.description.trim() ||
        !DateUtils.isSameDay(occurredOn, initial.occurredOn);
    final validation = widget.validator(
      cents: cents,
      occurredOn: occurredOn,
      description: descriptionController.text,
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
    category = widget.initialExpense?.category ?? .other;
    occurredOn =
        widget.initialExpense?.occurredOn ?? DateUtils.dateOnly(.now());
    descriptionController.addListener(_refreshSubmit);
  }

  @override
  void dispose() {
    descriptionController.removeListener(_refreshSubmit);
    descriptionController.dispose();
    super.dispose();
  }

  void _refreshSubmit() {
    if (mounted) {
      setState(() {});
    }
  }

  void onDescriptionChanged(String value) {
    setState(() {
      descriptionFailure = null;
      if (_selectedSuggestion != null && !hasManualAmount) {
        cents = 0;
      }

      _selectedSuggestion = null;
    });
  }

  void selectSuggestion(ExpenseSuggestionEntity suggestion) {
    if (!widget.enabled || _isRunning || isEditing) {
      return;
    }

    setState(() {
      _selectedSuggestion = suggestion;
      category = suggestion.category;
      descriptionFailure = null;
      if (!hasManualAmount) {
        cents = suggestion.cents ?? 0;
        if (suggestion.cents != null) {
          centsFailure = null;
        }
      }
    });
    if (cents != 0) {
      context.dismissKeyboard();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        selectAmount();
      }
    });
  }

  void applySuggestedAmount() {
    final amount = _selectedSuggestion?.cents;
    if (amount == null || !widget.enabled || _isRunning) {
      return;
    }

    setState(() {
      cents = amount;
      centsFailure = null;
      hasManualAmount = false;
    });
  }

  Future<void> selectAmount() async {
    if (!widget.enabled || _isRunning || _isPickerOpen) {
      return;
    }

    _isPickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final selectedCents = await showBottomSheetWidget<int>(
        context: context,
        title: 'Valor do gasto',
        child: CentsCalculatorWidget(
          value: cents,
          formatter: widget.moneyFormatter,
        ),
      );

      if (!mounted) {
        return;
      }

      context.dismissKeyboard();

      if (selectedCents == null || _isRunning) {
        return;
      }

      setState(() {
        cents = selectedCents;
        hasManualAmount = true;
        centsFailure = null;
      });
    } finally {
      _isPickerOpen = false;
    }
  }

  Future<void> selectCategory() async {
    if (!widget.enabled || _isRunning || _isPickerOpen) {
      return;
    }

    _isPickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final selectedCategory = await showBottomSheetWidget<ExpenseCategoryEnum>(
        context: context,
        title: 'Categoria do gasto',
        subtitle: 'Escolha onde esse gasto se encaixa.',
        contentPadding: const .all(16.0),
        child: ExpenseCategoryPickerWidget(value: category),
      );
      if (!mounted) {
        return;
      }

      context.dismissKeyboard();

      if (selectedCategory == null || _isRunning) {
        return;
      }

      setState(() => category = selectedCategory);
    } finally {
      _isPickerOpen = false;
    }
  }

  Future<void> selectDate() async {
    if (!widget.enabled || _isRunning || _isPickerOpen) {
      return;
    }

    _isPickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final selectedDate = await showBottomSheetWidget<DateTime>(
        context: context,
        title: 'Data do gasto',
        child: ExpenseDatePickerWidget(date: occurredOn),
      );

      if (!mounted) {
        return;
      }

      context.dismissKeyboard();

      if (selectedDate == null || _isRunning) {
        return;
      }

      setState(() {
        occurredOn = selectedDate;
        dateFailure = null;
      });
    } finally {
      _isPickerOpen = false;
    }
  }

  void submitAndContinue() => submit(keepFormOpen: true);

  void submit({bool keepFormOpen = false}) {
    if (!mounted || !canSubmit || _isRunning || _isPickerOpen) {
      return;
    }

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
        _submitUpdate(
          validCents: validCents,
          validDescription: validDescription,
          validDate: validDate,
        );
        return;
      }

      widget.expenseBloc.add(
        ExpenseSubmittedEvent(
          keepFormOpen: keepFormOpen,
          category: category,
          cents: validCents,
          occurredOn: validDate,
          description: validDescription,
        ),
      );
    }
  }

  void _submitUpdate({
    required int validCents,
    required String validDescription,
    required DateTime validDate,
  }) {
    final initial = widget.initialExpense!;

    widget.expenseBloc.add(
      ExpenseSubmittedEvent(
        id: widget.id!,
        category: category == initial.category ? null : category,
        cents: validCents == initial.cents.cents ? null : validCents,
        description: validDescription == initial.description.trim()
            ? null
            : validDescription,
        occurredOn: DateUtils.isSameDay(validDate, initial.occurredOn)
            ? null
            : validDate,
      ),
    );
  }

  void handleState(ExpenseState state) {
    if (!mounted || !widget.enabled) {
      return;
    }

    switch (state) {
      case ExpenseSubmissionFailure(:final errors):
        _showErrors(errors);
      case ExpenseSuccess():
        _completeSubmission(state);
      default:
        break;
    }
  }

  void _completeSubmission(ExpenseSuccess success) {
    context.showToast(
      variant: .success,
      title: success.isEditing ? 'Gasto atualizado' : 'Gasto cadastrado',
      description: success.isEditing
          ? 'Seu gasto foi atualizado com sucesso.'
          : 'Seu gasto foi cadastrado com sucesso.',
    );

    switch (success) {
      case ExpenseSuccess(isEditing: true):
        context.pop(success.expense);
      case ExpenseSuccess(keepFormOpen: true):
        _resetForm();
      case ExpenseSuccess() when widget.returnToPrevious:
        context.pop(success.expense);
      default:
        context.navigate(RouteEnum.dashboard.path);
    }
  }

  void _resetForm() {
    descriptionController.clear();

    setState(() {
      cents = 0;
      category = .other;
      hasManualAmount = false;
      _selectedSuggestion = null;
      dateFailure = null;
      centsFailure = null;
      descriptionFailure = null;
      occurredOn = DateUtils.dateOnly(.now());
    });
  }

  void _showErrors(ErrorsEntity errors) {
    final fields = ExpenseErrorMessageFormatter.fields(
      errors,
      isEditing: isEditing,
    );

    setState(() {
      centsFailure = fields.cents;
    });

    if (fields.toast case final message?) {
      context.showToast(
        variant: .error,
        title: isEditing
            ? 'Erro ao atualizar gasto'
            : 'Erro ao cadastrar gasto',
        description: message,
      );
    }
  }
}
