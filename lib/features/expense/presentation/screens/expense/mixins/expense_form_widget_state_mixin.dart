import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_date_picker_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/calculator/cents_calculator_widget.dart';

mixin ExpenseFormWidgetStateMixin on State<ExpenseFormWidget> {
  final descriptionController = TextEditingController();

  int cents = 0;
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
    if (!isEditing) return true;
    final initial = widget.initialExpense!;
    final hasChanges =
        cents != initial.cents.cents ||
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
    if (mounted) setState(() {});
  }

  void onDescriptionChanged(String value) {
    setState(() {
      descriptionFailure = null;
      if (_selectedSuggestion != null && !hasManualAmount) cents = 0;
      _selectedSuggestion = null;
    });
  }

  void selectSuggestion(ExpenseSuggestionEntity suggestion) {
    if (!widget.enabled || _isRunning || isEditing) return;
    setState(() {
      _selectedSuggestion = suggestion;
      descriptionFailure = null;
      if (!hasManualAmount) {
        cents = suggestion.cents ?? 0;
        if (suggestion.cents != null) centsFailure = null;
      }
    });
    if (cents == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) selectAmount();
      });
    } else {
      context.dismissKeyboard();
    }
  }

  void applySuggestedAmount() {
    final amount = _selectedSuggestion?.cents;
    if (amount == null || !widget.enabled || _isRunning) return;
    setState(() {
      cents = amount;
      centsFailure = null;
      hasManualAmount = false;
    });
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
        hasManualAmount = true;
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
        widget.expenseBloc.add(
          ExpenseSubmittedEvent(
            id: widget.id!,
            cents: validCents == initial.cents.cents ? null : validCents,
            description: validDescription == initial.description.trim()
                ? null
                : validDescription,
            occurredOn: DateUtils.isSameDay(validDate, initial.occurredOn)
                ? null
                : validDate,
          ),
        );
        return;
      }
      widget.expenseBloc.add(
        ExpenseSubmittedEvent(
          keepFormOpen: keepFormOpen,
          cents: validCents,
          occurredOn: validDate,
          description: validDescription,
        ),
      );
    }
  }

  void handleState(ExpenseState state) {
    if (!mounted || !widget.enabled) return;
    if (state case ExpenseSubmissionFailure(:final errors)) {
      _showErrors(errors);
    } else if (state case ExpenseSuccess(
      :final expense,
      :final isEditing,
      :final keepFormOpen,
    )) {
      context.showToast(
        variant: .success,
        title: isEditing ? 'Gasto atualizado' : 'Gasto cadastrado',
        description: isEditing
            ? 'Seu gasto foi atualizado com sucesso.'
            : 'Seu gasto foi cadastrado com sucesso.',
      );
      if (isEditing) {
        context.pop(expense);
      } else if (keepFormOpen) {
        _resetForm();
      } else if (widget.returnToPrevious) {
        context.pop(expense);
      } else {
        context.navigate(RouteEnum.dashboard.path);
      }
    }
  }

  void _resetForm() {
    descriptionController.clear();

    setState(() {
      cents = 0;
      hasManualAmount = false;
      _selectedSuggestion = null;
      dateFailure = null;
      centsFailure = null;
      descriptionFailure = null;
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
      if (error.status != '422' && error.status != '400') {
        remaining.add(error);
        continue;
      }

      switch (error.pointer) {
        case '/data/attributes/amount':
        case '/amount':
          amountMessages.add(message);
        case '/data/attributes/description':
        case '/description':
          descriptionMessages.add(message);
        case '/data/attributes/occurred_on':
        case '/occurred_on':
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

    if (remaining.isNotEmpty || errors.errors.isEmpty) {
      context.showToast(
        variant: .error,
        title:
            remaining.firstOrNull?.title ??
            (isEditing ? 'Erro ao atualizar gasto' : 'Erro ao cadastrar gasto'),
        description: remaining.isEmpty
            ? (isEditing
                  ? 'Não foi possível atualizar o gasto. Tente novamente.'
                  : 'Não foi possível cadastrar o gasto. Tente novamente.')
            : remaining
                  .map(
                    (error) =>
                        error.detail ?? error.title ?? 'Tente novamente.',
                  )
                  .join('\n'),
      );
    }
  }
}
