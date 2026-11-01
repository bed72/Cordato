import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_state.dart';

import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/dashboard_month_selector_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/mixins/dashboard_screen_state_mixin.dart';

final class const DashboardScreen({
  super.key,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final DashboardBloc Function() bloc,
}) extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

final class _DashboardScreenState extends State<DashboardScreen>
    with DashboardScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: BlocBuilder<DashboardBloc, DashboardState>(
        bloc: bloc,
        builder: (_, state) => state.hasFinancialError
            ? ErrorScreen(
                actionLabel: 'Tentar novamente',
                title: 'Não foi possível carregar sua Dashboard.',
                description: 'Não conseguimos carregar suas informações agora.',
                onAction: state.canRetry
                    ? () => bloc.add(DashboardRetryRequested())
                    : null,
              )
            : Scaffold(
                appBar: AppBarDashboardWidget(
                  user: state.user,
                  isLoading: state.isLoading,
                ),
                body: SafeArea(
                  child: RefreshIndicator(
                    onRefresh: refreshDashboard,
                    child: ListView(
                      padding: const .only(top: 20.0, bottom: 96.0),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        DashboardMonthSelectorWidget(
                          selectedMonth: state.selectedMonth,
                          formatter: widget.dateFormatter,
                          isLoading: state.isLoading,
                          showNavigation: state.canGoBack || state.canGoForward,
                          onPreviousMonth: state.canGoBack && !state.isLoading
                              ? () =>
                                    bloc.add(DashboardPreviousMonthRequested())
                              : null,
                          onNextMonth: state.canGoForward && !state.isLoading
                              ? () => bloc.add(DashboardNextMonthRequested())
                              : null,
                        ),
                        MetricsSectionWidget(
                          key: ValueKey(('metrics', state.selectedMonth)),
                          metrics: state.metrics,
                          moneyFormatter: widget.moneyFormatter,
                        ),
                        ExpensesSectionWidget(
                          limit: 6,
                          page: state.expenses,
                          dateFormatter: widget.dateFormatter,
                          moneyFormatter: widget.moneyFormatter,
                        ),
                      ],
                    ),
                  ),
                ),
                floatingActionButtonLocation: .endFloat,
                floatingActionButton: const ActionButtonDashboardWidget(),
              ),
      ),
    );
  }
}
