import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';
import 'package:cordato/features/core/presentation/widgets/empty_state_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_state.dart';

import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/dashboard_month_selector_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_section_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/mixins/dashboard_screen_state_mixin.dart';

final class const DashboardScreen({
  super.key,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final DashboardBloc Function() dashboardBloc,
  required final SpeechBloc speechBloc,
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
                description:
                    'Não conseguimos carregar suas informações agora...',
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
                  bottom: false,
                  child: RefreshIndicator(
                    onRefresh: refreshDashboard,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const .only(top: 20.0),
                          sliver: SliverToBoxAdapter(
                            child: DashboardMonthSelectorWidget(
                              isLoading: state.isLoading,
                              formatter: widget.dateFormatter,
                              selectedMonth: state.selectedMonth,
                              showNavigation:
                                  state.canGoBack || state.canGoForward,
                              onPreviousMonth:
                                  state.canGoBack && !state.isLoading
                                  ? () => bloc.add(
                                      DashboardPreviousMonthRequested(),
                                    )
                                  : null,
                              onNextMonth:
                                  state.canGoForward && !state.isLoading
                                  ? () =>
                                        bloc.add(DashboardNextMonthRequested())
                                  : null,
                            ),
                          ),
                        ),
                        if (state.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: .only(
                                bottom:
                                    96.0 + MediaQuery.paddingOf(context).bottom,
                              ),
                              child: EmptyStateWidget(
                                icon: Icons.receipt_long_outlined,
                                title: state.hasNoExpenseHistory
                                    ? 'Seu primeiro gasto começa aqui'
                                    : 'Nenhum gasto neste mês',
                                description: state.hasNoExpenseHistory
                                    ? 'Registre uma despesa para começar...'
                                    : 'Seus gastos do mês aparecerão aqui...',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: .only(
                              bottom:
                                  96.0 + MediaQuery.paddingOf(context).bottom,
                            ),
                            sliver: SliverList.list(
                              children: [
                                MetricsSectionWidget(
                                  key: ValueKey((
                                    'metrics',
                                    state.selectedMonth,
                                  )),
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
                      ],
                    ),
                  ),
                ),
                floatingActionButtonLocation: .endFloat,
                floatingActionButton: ActionButtonDashboardWidget(
                  bloc: widget.speechBloc,
                ),
              ),
      ),
    );
  }
}
