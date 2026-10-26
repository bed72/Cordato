import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';

mixin ExpenseScreenStateMixin on State<ExpenseScreen> {
  late ExpenseBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.expenseBloc();
    loadExpense();
  }

  @override
  void didUpdateWidget(ExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenseBloc != widget.expenseBloc ||
        oldWidget.id != widget.id) {
      if (oldWidget.expenseBloc != widget.expenseBloc) {
        bloc.close();
        bloc = widget.expenseBloc();
      }
      loadExpense();
    }
  }

  void loadExpense() {
    bloc.add(ExpenseRequestedEvent(id: widget.id));
  }

  @override
  void dispose() {
    bloc.close();
    super.dispose();
  }
}
