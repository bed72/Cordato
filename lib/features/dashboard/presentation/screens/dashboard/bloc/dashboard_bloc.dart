import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_state.dart';

final class DashboardBloc({
  required final IUserRepository _userRepository,
  required final IExpenseRepository _expenseRepository,
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
        final user = await _getUser(emit);
        if (!_active(emit)) return;
        emit(
          DashboardState(
            user: user,
            phase: .ready,
            selectedMonth: month,
            metrics: previous.metrics,
            expenses: previous.expenses,
            firstMonth: previous.firstMonth,
            currentMonth: previous.currentMonth,
          ),
        );
        return;
      }
      final (user, history) = await (_getUser(emit), _getHistory()).wait;
      if (!_active(emit)) return;
      final date = history?.items.firstOrNull?.occurredOn;
      final firstMonth = date == null ? null : DateTime(date.year, date.month);
      if (history != null) {
        final minimum =
            firstMonth == null || firstMonth.isAfter(previous.currentMonth)
            ? previous.currentMonth
            : firstMonth;
        if (month.isBefore(minimum)) month = minimum;
      }
      final end = DateTime(month.year, month.month + 1, 0);
      final (metrics, expenses) = await (
        Future.sync(
          () => _metricsRepository.getExpenses(
            startDate: month,
            endDate: end,
            groupBy: .category,
          ),
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
          expenses: expenses,
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
            UserException(:final errors) => errors,
            MetricsException(:final errors) => errors,
            ExpenseException(:final errors) => errors,
            ParallelWaitError(
              errors: (AsyncError(error: UserException(:final errors)), null),
            ) =>
              errors,
            ParallelWaitError(
              errors: (
                AsyncError(error: MetricsException(:final errors)),
                null,
              ),
            ) =>
              errors,
            ParallelWaitError(
              errors: (
                null,
                AsyncError(error: ExpenseException(:final errors)),
              ),
            ) =>
              errors,
            _ => .unknown(),
          },
        ),
      );
    }
  }

  Future<UserEntity> _getUser(Emitter<DashboardState> emit) async {
    try {
      return await _userRepository.getById();
    } on UserException {
      rethrow;
    } catch (error, stackTrace) {
      if (_active(emit)) addError(error, stackTrace);
      rethrow;
    }
  }

  Future<ExpensePageEntity?> _getHistory() async {
    try {
      return await _expenseRepository.get(pageSize: 1, sort: 'occurred_on');
    } catch (_) {
      return null;
    }
  }
}
