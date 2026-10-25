import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/expense/presentation/screens/expense/expense_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';

mixin ExpenseScreenStateMixin on State<ExpenseScreen> {
  late ExpenseBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
    loadExpense();
  }

  @override
  void didUpdateWidget(ExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc != widget.bloc || oldWidget.id != widget.id) {
      if (oldWidget.bloc != widget.bloc) {
        bloc.close();
        bloc = widget.bloc();
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
