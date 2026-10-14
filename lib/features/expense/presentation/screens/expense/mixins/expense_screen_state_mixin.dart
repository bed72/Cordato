import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';

mixin ExpenseScreenStateMixin on State<ExpenseScreen> {
  int _queryRevision = 0;
  bool _loadPending = false;

  String loadErrorDescription(Object error) {
    final errors = error is CommandFailureException
        ? error.errors
        : ErrorsEntity.unknown();
    if (errors.errors.isEmpty) {
      return 'Tente novamente para carregar os dados.';
    }
    return errors.errors
        .map((error) => error.detail ?? error.title ?? 'Tente novamente.')
        .join('\n');
  }

  @override
  void initState() {
    super.initState();
    widget.getCommand.execute.isRunning.addListener(_loadingChanged);
    _requestExpense();
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
      oldWidget.getCommand.execute.isRunning.removeListener(_loadingChanged);
      oldWidget.getCommand.dispose();
      widget.getCommand.execute.isRunning.addListener(_loadingChanged);
    }
    if (oldWidget.id != widget.id ||
        oldWidget.getCommand != widget.getCommand) {
      _queryRevision++;
      _requestExpense();
    }
  }

  @override
  void dispose() {
    _queryRevision++;
    _loadPending = false;
    widget.getCommand.execute.isRunning.removeListener(_loadingChanged);
    widget.getCommand.dispose();
    widget.createCommand.dispose();
    widget.updateCommand.dispose();

    super.dispose();
  }

  void loadExpense() {
    if (!mounted || widget.getCommand.execute.isRunning.value) return;
    _requestExpense();
  }

  void _requestExpense() {
    _loadPending = widget.id != null;
    _loadPendingExpense();
  }

  void _loadPendingExpense() {
    if (!mounted ||
        !_loadPending ||
        widget.getCommand.execute.isRunning.value) {
      return;
    }
    final id = widget.id;
    _loadPending = false;
    if (id != null) widget.getCommand.execute.run(id);
  }

  void _loadingChanged() {
    if (!mounted ||
        !_loadPending ||
        widget.getCommand.execute.isRunning.value) {
      return;
    }
    final command = widget.getCommand;
    final revision = _queryRevision;
    Future<void>.microtask(() {
      if (!mounted ||
          revision != _queryRevision ||
          command != widget.getCommand) {
        return;
      }

      _loadPendingExpense();
    });
  }
}
