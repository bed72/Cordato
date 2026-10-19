import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ActionButtonDashboardWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BounceWidget.withoutOnPress(
      child: FloatingActionButton(
        elevation: 0.0,
        onPressed: () => _openExpense(context),
        tooltip: 'Adicionar gasto',
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: context.radius.cornerRadius100,
        ),
        child: const IconWidget(size: 20.0, icon: Icons.receipt_long_outlined),
      ),
    );
  }

  Future<void> _openExpense(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final bloc = context.read<DashboardBloc>();
    bool changed = false;
    await context.pushNamed(
      RouteEnum.expense.path,
      arguments: (
        returnToPrevious: true,
        onExpensesChanged: () => changed = true,
      ),
    );
    if (changed &&
        context.mounted &&
        !bloc.isClosed &&
        identical(context.read<DashboardBloc>(), bloc)) {
      bloc.add(DashboardExpensesChanged());
    }
  }
}
