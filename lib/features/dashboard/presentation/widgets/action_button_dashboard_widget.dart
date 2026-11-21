import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expense_action_button_widget.dart';

final class const ActionButtonDashboardWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ExpenseActionButtonWidget(onTap: () => _openExpense(context)),
    );
  }

  Future<void> _openExpense(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    final bloc = context.read<DashboardBloc>();
    final expense = await context.pushNamed<ExpenseEntity>(
      RouteEnum.expense.path,
      arguments: (returnToPrevious: true),
    );

    if (expense != null &&
        context.mounted &&
        !bloc.isClosed &&
        identical(context.read<DashboardBloc>(), bloc)) {
      bloc.add(DashboardExpensesChanged());
    }
  }
}
