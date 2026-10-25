import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_state.dart';

final class DashboardBloc({
  required final IUserRepository _userRepository,
  required final IExpenseRepository _expenseRepository,
  required final IInsightRepository _insightRepository,
  required final IMetricsRepository _metricsRepository,
}) extends Bloc<DashboardEvent, DashboardState> {
  bool _opened = false;

  this : super(DashboardState()) {
    on<DashboardEvent>(
      _load,
      transformer: (events, mapper) =>
          restartable<DashboardEvent>()(events.where(_accept), mapper),
    );
  }

  bool _accept(DashboardEvent event) {
    if (isClosed) return false;

    return switch (event) {
      DashboardOpened() => !_opened,
      DashboardRetryRequested() => state.canRetry,
      DashboardRefreshRequested() => state.canRefresh,
      DashboardNextMonthRequested() => state.canGoForward,
      DashboardPreviousMonthRequested() => state.canGoBack,
      DashboardExpensesChanged() || DashboardUserRequested() => true,
    };
  }

  bool _active(Emitter<DashboardState> emit) => !isClosed && !emit.isDone;

  T _value<T>(Either<ErrorsEntity, T> data) => switch (data) {
    Right(:final value) => value,
    Left(:final value) => throw value,
  };

  Future<void> _load(DashboardEvent event, Emitter<DashboardState> emit) async {
    final previous = state;
    final userOnly =
        event is DashboardUserRequested && previous.phase == .ready;
    final offset = switch (event) {
      DashboardPreviousMonthRequested() => -1,
      DashboardNextMonthRequested() => 1,
      _ => 0,
    };

    DateTime month = DateTime(
      previous.selectedMonth.year,
      previous.selectedMonth.month + offset,
    );

    _opened = true;

    emit(
      DashboardState(currentMonth: previous.currentMonth, selectedMonth: month),
    );

    try {
      if (userOnly) {
        final user = await _getUser();
        if (!_active(emit)) return;
        emit(
          DashboardState(
            user: user,
            phase: .ready,
            selectedMonth: month,
            metrics: previous.metrics,
            expenses: previous.expenses,
            insights: previous.insights,
            firstMonth: previous.firstMonth,
            currentMonth: previous.currentMonth,
          ),
        );
        return;
      }
      final (user, history) = await (_getUser(), _getHistory()).wait;
      if (!_active(emit)) return;
      final date = history is Right<ErrorsEntity, ExpensePageEntity>
          ? history.value.items.firstOrNull?.occurredOn
          : null;
      final firstMonth = date == null ? null : DateTime(date.year, date.month);
      if (history is Right<ErrorsEntity, ExpensePageEntity>) {
        final minimum =
            firstMonth == null || firstMonth.isAfter(previous.currentMonth)
            ? previous.currentMonth
            : firstMonth;
        if (month.isBefore(minimum)) month = minimum;
      }
      final end = DateTime(month.year, month.month + 1, 0);
      final (metrics, insights, expenses) = await (
        Future.sync(
          () => _metricsRepository.getExpenses(
            startDate: month,
            endDate: end,
            groupBy: .category,
          ),
        ),
        Future.sync(
          () => _insightRepository.get(year: month.year, month: month.month),
        ),
        Future.sync(
          () => _expenseRepository.get(pageSize: 6, from: month, to: end),
        ),
      ).wait;
      if (!_active(emit)) return;
      emit(
        DashboardState(
          currentMonth: previous.currentMonth,
          selectedMonth: month,
          phase: .ready,
          firstMonth: firstMonth,
          user: user,
          metrics: metrics,
          insights: .unmodifiable(_value(insights)),
          expenses: _value(expenses),
        ),
      );
    } catch (error) {
      if (!_active(emit)) return;
      emit(
        DashboardState(
          currentMonth: previous.currentMonth,
          selectedMonth: month,
          phase: .failure,
          financialError: switch (error) {
            ErrorsEntity() => error,
            MetricsException(:final errors) => errors,
            ParallelWaitError(
              errors: (
                AsyncError(error: MetricsException(:final errors)),
                null,
                null,
              ),
            ) =>
              errors,
            _ => .unknown(),
          },
        ),
      );
    }
  }

  Future<UserEntity?> _getUser() async {
    try {
      return await _userRepository.getById();
    } catch (_) {
      return null;
    }
  }

  Future<Either<ErrorsEntity, ExpensePageEntity>> _getHistory() async {
    try {
      return await _expenseRepository.get(pageSize: 1, sort: 'occurred_on');
    } catch (_) {
      return Left(.unknown());
    }
  }
}
