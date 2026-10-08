import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';

mixin ExpenseScreenStateMixin on State<ExpenseScreen> {
  bool isLoading = false;
  ExpenseEntity? expense;
  ErrorsEntity? loadErrors;

  String get loadErrorDescription =>
      loadErrors?.errors
          .map((error) => error.detail ?? error.title ?? 'Tente novamente.')
          .join('\n') ??
      'Tente novamente para carregar os dados.';

  @override
  void initState() {
    super.initState();
    loadExpense();
  }

  @override
  void didUpdateWidget(ExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createCommand != widget.createCommand) {
      oldWidget.createCommand.dispose();
    }
    if (oldWidget.updateCommand != widget.updateCommand) {
      oldWidget.updateCommand.dispose();
    }
    if (oldWidget.getCommand != widget.getCommand) {
      oldWidget.getCommand.dispose();
    }
    if (oldWidget.id != widget.id ||
        oldWidget.getCommand != widget.getCommand) {
      expense = null;
      loadErrors = null;
      isLoading = widget.id != null;
      loadExpense();
    }
  }

  @override
  void dispose() {
    widget.getCommand.dispose();
    widget.createCommand.dispose();
    widget.updateCommand.dispose();

    super.dispose();
  }

  Future<void> loadExpense() async {
    final id = widget.id;
    final command = widget.getCommand;
    if (id == null || command.execute.isRunning.value) return;

    setState(() {
      isLoading = true;
      loadErrors = null;
    });
    try {
      final result = await command.execute.runAsync(id);
      if (!mounted || widget.getCommand != command || widget.id != id) return;
      setState(() {
        switch (result) {
          case Right(:final value):
            expense = value;
          case Left(:final value):
            loadErrors = value;
          case null:
            loadErrors = .unknown();
        }
      });
    } catch (_) {
      if (!mounted || widget.getCommand != command || widget.id != id) return;
      setState(() => loadErrors = .unknown());
    } finally {
      if (mounted && widget.getCommand == command) {
        if (widget.id == id) {
          setState(() => isLoading = false);
        } else {
          loadExpense();
        }
      }
    }
  }
}
