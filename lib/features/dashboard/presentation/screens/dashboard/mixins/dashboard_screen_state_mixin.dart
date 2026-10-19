import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';

mixin DashboardScreenStateMixin on State<DashboardScreen> {
  late DashboardBloc bloc;

  @override
  void initState() {
    super.initState();

    bloc = widget.bloc()..add(DashboardOpened());
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) return;
    unawaited(bloc.close());
    bloc = widget.bloc()..add(DashboardOpened());
  }

  Future<void> refreshDashboard() async {
    final captured = bloc;
    if (!captured.state.canRefresh) return;
    final completed = captured.stream.firstWhere(
      (state) => !state.isLoading,
      orElse: () => captured.state,
    );
    captured.add(DashboardRefreshRequested());
    await completed;
  }

  @override
  void dispose() {
    unawaited(bloc.close());
    super.dispose();
  }
}
