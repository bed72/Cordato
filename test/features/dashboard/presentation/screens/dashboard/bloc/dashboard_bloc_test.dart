import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart'
    as expense;
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart'
    as insight;
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_state.dart';
import 'package:cordato/features/dashboard/presentation/enums/dashboard_phase_enum.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';
import '../../../../../../support/expense/mocks/expense_repository_mock.dart';
import '../../../../../../support/insight/mocks/insight_repository_mock.dart';
import '../../../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  late DashboardBloc bloc;
  late UserRepositoryMock users;
  late ExpenseRepositoryMock expenses;
  late InsightRepositoryMock insights;
  late MetricsRepositoryMock metricsRepository;
  late List<StreamSubscription<DashboardState>> subscriptions;
  final today = DateTime(2026, 10, 19, 16, 30);
  const profile = UserEntity(
    id: 'user',
    name: 'Gabriel',
    email: 'a@b.com',
    status: 'active',
  );

  ExpensePageEntity page(List<DateTime> dates, {String? next}) =>
      ExpensePageEntity(
        next: next,
        prev: null,
        items: [
          for (final date in dates)
            ExpenseEntity(
              id: date.toIso8601String(),
              category: .food,
              occurredOn: date,
              description: 'Despesa',
              cents: .create(cents: 100).right,
            ),
        ],
      );

  ExpenseMetricsEntity totals(DateTime month, {int cents = 0}) =>
      ExpenseMetricsEntity(
        id: 'metrics',
        startDate: month,
        endDate: DateTime(month.year, month.month + 1, 0),
        totalAmount: cents,
        categories: const [],
      );

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  Future<expense.GetRepositoryType> history() =>
      expenses.get(pageSize: 1, sort: 'occurred_on');

  DashboardBloc create({DateTime? date}) {
    final bloc = DashboardBloc(
      userRepository: users,
      expenseRepository: expenses,
      insightRepository: insights,
      metricsRepository: metricsRepository,
    );
    bloc.emit(DashboardState(currentMonth: date ?? today));
    return bloc;
  }

  Future<void> send(DashboardEvent event) async {
    bloc.add(event);
    await flush();
  }

  List<DashboardState> recordStates() {
    final states = <DashboardState>[];
    subscriptions.add(bloc.stream.listen(states.add));
    return states;
  }

  void stubMetrics(Future<ExpenseMetricsEntity> Function() response) {
    when(
      () => metricsRepository.getExpenses(
        groupBy: .category,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) => response());
  }

  void stubInsights(Future<insight.GetRepositoryType> Function() response) {
    when(
      () => insights.get(
        year: any(named: 'year'),
        month: any(named: 'month'),
      ),
    ).thenAnswer((_) => response());
  }

  void stubRecent(Future<expense.GetRepositoryType> Function() response) {
    when(
      () => expenses.get(
        pageSize: 6,
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) => response());
  }

  setUp(() {
    subscriptions = [];
    users = UserRepositoryMock();
    expenses = ExpenseRepositoryMock();
    insights = InsightRepositoryMock();
    metricsRepository = MetricsRepositoryMock();
    when(() => users.getById()).thenAnswer((_) async => profile);
    when(history).thenAnswer((_) async => Right(page([DateTime(2024, 1)])));
    stubRecent(() async => Right(page([])));
    stubInsights(() async => const Right([]));
    when(
      () => metricsRepository.getExpenses(
        groupBy: .category,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer(
      (call) async => totals(call.namedArguments[#startDate] as DateTime),
    );
    bloc = create();
  });

  tearDown(() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await bloc.close();
  });

  test(
    'starts in the current civil month without querying before opening',
    () async {
      await bloc.close();
      final now = DateTime.now();
      bloc = DashboardBloc(
        userRepository: users,
        expenseRepository: expenses,
        insightRepository: insights,
        metricsRepository: metricsRepository,
      );
      expect(bloc.state.currentMonth, DateTime(now.year, now.month));
      expect(bloc.state.selectedMonth, DateTime(now.year, now.month));
      expect(bloc.state.phase, DashboardPhaseEnum.loading);
      verifyZeroInteractions(users);
      verifyZeroInteractions(expenses);
      verifyZeroInteractions(insights);
      verifyZeroInteractions(metricsRepository);
    },
  );

  test('opens once and publishes all data in a single ready state', () async {
    final states = recordStates();
    await send(DashboardOpened());
    expect(states.map((state) => state.phase), [
      DashboardPhaseEnum.loading,
      DashboardPhaseEnum.ready,
    ]);
    expect(bloc.state.user, same(profile));
    expect(bloc.state.metrics!.totalAmount, 0);
    expect(bloc.state.expenses!.items, isEmpty);
    expect(bloc.state.insights, isEmpty);
    expect(bloc.state.firstMonth, DateTime(2024, 1));
    await send(DashboardOpened());
    expect(states.length, 2);
    verify(() => users.getById()).called(1);
    verify(history).called(1);
    verify(
      () => metricsRepository.getExpenses(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        groupBy: .category,
      ),
    ).called(1);
    verify(() => insights.get(year: 2026, month: 10)).called(1);
    verify(
      () => expenses.get(
        pageSize: 6,
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      ),
    ).called(1);
    verifyNoMoreInteractions(expenses);
  });

  test(
    'reads User and history in parallel before starting the sections',
    () async {
      final pendingUser = Completer<UserEntity>();
      final pendingHistory = Completer<expense.GetRepositoryType>();
      when(() => users.getById()).thenAnswer((_) => pendingUser.future);
      when(history).thenAnswer((_) => pendingHistory.future);
      await send(DashboardOpened());
      verify(() => users.getById()).called(1);
      verify(history).called(1);
      verifyZeroInteractions(metricsRepository);
      verifyZeroInteractions(insights);
      pendingUser.complete(profile);
      await flush();
      expect(bloc.state.user, isNull);
      verifyZeroInteractions(metricsRepository);
      pendingHistory.complete(Right(page([])));
      await flush();
      expect(bloc.state.phase, DashboardPhaseEnum.ready);
    },
  );

  test(
    'does not publish completed sections while another section is pending',
    () async {
      final states = recordStates();
      final pendingMetrics = Completer<ExpenseMetricsEntity>();
      final pendingInsights = Completer<insight.GetRepositoryType>();
      final pendingExpenses = Completer<expense.GetRepositoryType>();
      stubMetrics(() => pendingMetrics.future);
      stubInsights(() => pendingInsights.future);
      stubRecent(() => pendingExpenses.future);
      await send(DashboardOpened());
      pendingMetrics.complete(totals(DateTime(2026, 10)));
      pendingExpenses.complete(Right(page([])));
      await flush();
      expect(states.length, 1);
      expect(bloc.state.phase, DashboardPhaseEnum.loading);
      expect(bloc.state.user, isNull);
      expect(bloc.state.metrics, isNull);
      expect(bloc.state.expenses, isNull);
      expect(bloc.state.insights, isNull);
      pendingInsights.complete(const Right([]));
      await flush();
      expect(states.length, 2);
      expect(bloc.state.phase, DashboardPhaseEnum.ready);
      expect(() => bloc.state.insights!.clear(), throwsUnsupportedError);
    },
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Período inválido',
          pointer: '/data/attributes/occurred_on',
          parameter: 'filter[from]',
        ),
      ],
    ),
  ]) {
    for (final section in ['metrics', 'insights', 'expenses']) {
      test(
        '$section preserves the original typed failure after every section completes with ${errors.errors.length} errors',
        () async {
          final pending = Completer<expense.GetRepositoryType>();
          stubRecent(() => pending.future);
          switch (section) {
            case 'metrics':
              stubMetrics(() async => throw MetricsException(errors: errors));
            case 'insights':
              stubInsights(() async => Left(errors));
            case 'expenses':
              stubMetrics(() async => totals(DateTime(2026, 10)));
          }
          final states = recordStates();
          await send(DashboardOpened());
          expect(bloc.state.phase, DashboardPhaseEnum.loading);
          pending.complete(
            section == 'expenses' ? Left(errors) : Right(page([])),
          );
          await flush();
          expect(states.map((state) => state.phase), [
            DashboardPhaseEnum.loading,
            DashboardPhaseEnum.failure,
          ]);
          expect(bloc.state.financialError, same(errors));
          expect(bloc.state.canRetry, isTrue);
          expect(bloc.state.metrics, isNull);
        },
      );
    }
  }

  test('unexpected section exceptions become unknown errors without partial publication', () async {
    stubMetrics(() => throw StateError('unexpected'));
    await send(DashboardOpened());
    expect(bloc.state.phase, DashboardPhaseEnum.failure);
    expect(bloc.state.financialError!.errors.first.title, 'Erro desconhecido');
    verify(() => insights.get(year: 2026, month: 10)).called(1);
  });

  for (final unexpected in [false, true]) {
    test(
      'auxiliary ${unexpected ? 'unexpected' : 'typed'} failures use fallbacks without a financial error',
      () async {
        when(() => users.getById()).thenAnswer((_) async {
          if (unexpected) throw StateError('user');
          throw UserException(errors: .unknown());
        });
        when(history).thenAnswer((_) async {
          if (unexpected) throw StateError('history');
          return Left(ErrorsEntity.unknown());
        });
        await send(DashboardOpened());
        expect(bloc.state.phase, DashboardPhaseEnum.ready);
        expect(bloc.state.user, isNull);
        expect(bloc.state.firstMonth, isNull);
        expect(bloc.state.canGoBack, isFalse);
        expect(bloc.state.financialError, isNull);
      },
    );
  }

  for (final date in [DateTime(2026, 1, 20), DateTime(2024, 3, 10)]) {
    test(
      'loads the complete civil interval across ${date.year}-${date.month}',
      () async {
        await bloc.close();
        when(history).thenAnswer((_) async => Right(page([DateTime(2020)])));
        bloc = create(date: date);
        await send(DashboardOpened());
        final states = recordStates();
        final month = DateTime(date.year, date.month - 1);
        final end = DateTime(date.year, date.month, 0);
        await send(DashboardPreviousMonthRequested());
        expect(states.map((state) => state.phase), [
          DashboardPhaseEnum.loading,
          DashboardPhaseEnum.ready,
        ]);
        expect(states.first.metrics, isNull);
        expect(states.first.expenses, isNull);
        expect(states.first.insights, isNull);
        expect(bloc.state.currentMonth, DateTime(date.year, date.month));
        expect(bloc.state.selectedMonth, month);
        verify(
          () => metricsRepository.getExpenses(
            startDate: month,
            endDate: end,
            groupBy: .category,
          ),
        ).called(1);
        verify(() => insights.get(year: month.year, month: month.month))
            .called(1);
        verify(() => expenses.get(pageSize: 6, from: month, to: end)).called(1);
        verify(() => users.getById()).called(2);
        verify(history).called(2);
      },
    );
  }

  test('blocks future months and months before the first expense', () async {
    when(history).thenAnswer((_) async => Right(page([DateTime(2026, 10)])));
    await send(DashboardOpened());
    final ready = bloc.state;
    clearInteractions(metricsRepository);
    await send(DashboardPreviousMonthRequested());
    await send(DashboardNextMonthRequested());
    expect(bloc.state, same(ready));
    verifyZeroInteractions(metricsRepository);
  });

  test(
    'returns to the current month without navigating into the future',
    () async {
      await send(DashboardOpened());
      await send(DashboardPreviousMonthRequested());
      expect(bloc.state.canGoForward, isTrue);
      await send(DashboardNextMonthRequested());
      expect(bloc.state.selectedMonth, DateTime(2026, 10));
      expect(bloc.state.canGoForward, isFalse);
    },
  );

  test('blocked events neither cancel nor queue work during loading', () async {
    final pending = Completer<ExpenseMetricsEntity>();
    stubMetrics(() => pending.future);
    await send(DashboardOpened());
    for (final event in <DashboardEvent>[
      DashboardOpened(),
      DashboardRefreshRequested(),
      DashboardRetryRequested(),
      DashboardPreviousMonthRequested(),
      DashboardNextMonthRequested(),
    ]) {
      bloc.add(event);
    }
    await flush();
    expect(bloc.state.isLoading, isTrue);
    pending.complete(totals(DateTime(2026, 10)));
    await flush();
    expect(bloc.state.phase, DashboardPhaseEnum.ready);
    verify(history).called(1);
    verify(() => users.getById()).called(1);
  });

  test('reads the first historical civil month once and ignores opaque continuations', () async {
    when(history).thenAnswer(
      (_) async => Right(
        page([
          DateTime.utc(2000, 2, 29, 23),
        ], next: 'https://other.example/?page[cursor]=opaque'),
      ),
    );
    await send(DashboardOpened());
    expect(bloc.state.firstMonth, DateTime(2000, 2));
    verify(history).called(1);
    verify(
      () => expenses.get(
        pageSize: 6,
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
      ),
    ).called(1);
    verifyNoMoreInteractions(expenses);
  });

  test('successful empty history has no previous month and does not fabricate a limit', () async {
    when(history).thenAnswer((_) async => Right(page([])));
    await send(DashboardOpened());
    expect(bloc.state.phase, DashboardPhaseEnum.ready);
    expect(bloc.state.firstMonth, isNull);
    expect(bloc.state.canGoBack, isFalse);
  });

  test(
    'refresh preserves the selected month when history still allows it',
    () async {
      await send(DashboardOpened());
      await send(DashboardPreviousMonthRequested());
      await send(DashboardRefreshRequested());
      expect(bloc.state.selectedMonth, DateTime(2026, 9));
      expect(bloc.state.metrics!.startDate, DateTime(2026, 9));
    },
  );

  for (final dates in [
    <DateTime>[],
    [DateTime(2026, 10)],
    [DateTime(2027)],
  ]) {
    test(
      'refresh adjusts selection for updated history $dates without passing the current month',
      () async {
        await send(DashboardOpened());
        await send(DashboardPreviousMonthRequested());
        when(history).thenAnswer((_) async => Right(page(dates)));
        await send(DashboardRefreshRequested());
        expect(bloc.state.selectedMonth, DateTime(2026, 10));
        expect(bloc.state.metrics!.startDate, DateTime(2026, 10));
        expect(bloc.state.canGoBack, isFalse);
        expect(bloc.state.canGoForward, isFalse);
      },
    );
  }

  test('history failure preserves a past selection and disables the previous month', () async {
    await send(DashboardOpened());
    await send(DashboardPreviousMonthRequested());
    when(history).thenAnswer((_) async => Left(ErrorsEntity.unknown()));
    await send(DashboardRefreshRequested());
    expect(bloc.state.selectedMonth, DateTime(2026, 9));
    expect(bloc.state.metrics!.startDate, DateTime(2026, 9));
    expect(bloc.state.canGoBack, isFalse);
    expect(bloc.state.canGoForward, isTrue);
  });

  test('retry is a normal load and clears the previous failure only with complete success', () async {
    stubMetrics(
      () async => throw MetricsException(errors: ErrorsEntity.unknown()),
    );
    await send(DashboardOpened());
    final failed = bloc.state;
    await send(DashboardRefreshRequested());
    await send(DashboardPreviousMonthRequested());
    expect(bloc.state, same(failed));
    final pendingUser = Completer<UserEntity>();
    when(() => users.getById()).thenAnswer((_) => pendingUser.future);
    stubMetrics(() async => totals(DateTime(2026, 10)));
    final states = recordStates();
    await send(DashboardRetryRequested());
    expect(bloc.state.phase, DashboardPhaseEnum.loading);
    expect(bloc.state.financialError, isNull);
    await send(DashboardRetryRequested());
    pendingUser.complete(profile);
    await flush();
    expect(states.map((state) => state.phase), [
      DashboardPhaseEnum.loading,
      DashboardPhaseEnum.ready,
    ]);
    verify(() => users.getById()).called(2);
  });

  test(
    'a failed retry returns to error without automatically retrying',
    () async {
      stubMetrics(
        () async => throw MetricsException(errors: ErrorsEntity.unknown()),
      );
      await send(DashboardOpened());
      final states = recordStates();
      await send(DashboardRetryRequested());
      expect(states.map((state) => state.phase), [
        DashboardPhaseEnum.loading,
        DashboardPhaseEnum.failure,
      ]);
      expect(bloc.state.canRetry, isTrue);
      verify(history).called(2);
    },
  );

  for (final staleError in [false, true]) {
    test(
      'confirmed changes replace a pending cycle and ignore old ${staleError ? 'errors' : 'data'}',
      () async {
        final pending = Completer<ExpenseMetricsEntity>();
        stubMetrics(() => pending.future);
        await send(DashboardOpened());
        stubMetrics(() async => totals(DateTime(2026, 10), cents: 700));
        await send(DashboardExpensesChanged());
        expect(bloc.state.metrics!.totalAmount, 700);
        final ready = bloc.state;
        if (staleError) {
          pending.completeError(StateError('obsolete'));
        } else {
          pending.complete(totals(DateTime(2026, 10), cents: 100));
        }
        await flush();
        expect(bloc.state, same(ready));
      },
    );
  }

  for (final event in <DashboardEvent>[
    DashboardRefreshRequested(),
    DashboardRetryRequested(),
  ]) {
    test(
      'confirmed changes replace ${event.runtimeType} without waiting for obsolete history',
      () async {
        if (event is DashboardRetryRequested) {
          stubMetrics(
            () async => throw MetricsException(errors: ErrorsEntity.unknown()),
          );
        }
        await send(DashboardOpened());
        final pending = Completer<expense.GetRepositoryType>();
        when(history).thenAnswer((_) => pending.future);
        await send(event);
        when(history).thenAnswer((_) async => Right(page([])));
        stubMetrics(() async => totals(DateTime(2026, 10)));
        await send(DashboardExpensesChanged());
        final ready = bloc.state;
        expect(ready.phase, DashboardPhaseEnum.ready);
        pending.complete(Right(page([DateTime(2000)])));
        await flush();
        expect(bloc.state, same(ready));
      },
    );
  }

  test(
    'returning from User with ready content reloads only the profile',
    () async {
      await send(DashboardOpened());
      final previous = bloc.state;
      clearInteractions(expenses);
      clearInteractions(insights);
      clearInteractions(metricsRepository);
      final states = recordStates();
      when(() => users.getById())
          .thenAnswer((_) async => throw UserException(errors: .unknown()));
      await send(DashboardUserRequested());
      expect(states.map((state) => state.phase), [
        DashboardPhaseEnum.loading,
        DashboardPhaseEnum.ready,
      ]);
      expect(states.first.metrics, isNull);
      expect(bloc.state.user, isNull);
      expect(bloc.state.metrics, same(previous.metrics));
      expect(bloc.state.insights, same(previous.insights));
      expect(bloc.state.expenses, same(previous.expenses));
      expect(bloc.state.firstMonth, previous.firstMonth);
      verifyZeroInteractions(expenses);
      verifyZeroInteractions(insights);
      verifyZeroInteractions(metricsRepository);
    },
  );

  test('returning from User during loading replaces the whole cycle without waiting for old User', () async {
    final pending = Completer<UserEntity>();
    when(() => users.getById()).thenAnswer((_) => pending.future);
    await send(DashboardOpened());
    when(() => users.getById()).thenAnswer((_) async => profile);
    await send(DashboardUserRequested());
    final ready = bloc.state;
    expect(ready.phase, DashboardPhaseEnum.ready);
    expect(ready.user, same(profile));
    pending.completeError(StateError('old User'));
    await flush();
    expect(bloc.state, same(ready));
    verify(history).called(2);
    verify(() => insights.get(year: 2026, month: 10)).called(1);
  });

  test('confirmed changes replace a pending profile refresh', () async {
    await send(DashboardOpened());
    final pending = Completer<UserEntity>();
    when(() => users.getById()).thenAnswer((_) => pending.future);
    await send(DashboardUserRequested());
    when(() => users.getById()).thenAnswer((_) async => profile);
    await send(DashboardExpensesChanged());
    final ready = bloc.state;
    pending.completeError(UserException(errors: .unknown()));
    await flush();
    expect(bloc.state, same(ready));
    expect(bloc.state.user, same(profile));
  });

  for (final pendingHistory in [false, true]) {
    test(
      'closing during ${pendingHistory ? 'history' : 'sections'} ignores late completion',
      () async {
        final oldHistory = Completer<expense.GetRepositoryType>();
        final oldMetrics = Completer<ExpenseMetricsEntity>();
        if (pendingHistory) {
          when(history).thenAnswer((_) => oldHistory.future);
        } else {
          stubMetrics(() => oldMetrics.future);
        }
        await send(DashboardOpened());
        final firstClose = bloc.close();
        expect(bloc.isClosed, isTrue);
        await firstClose;
        final closed = bloc.state;
        if (pendingHistory) {
          oldHistory.complete(
            Right(page([DateTime(2000)], next: '?page[after]=late')),
          );
        } else {
          oldMetrics.completeError(StateError('late metrics'));
        }
        await flush();
        expect(bloc.state, same(closed));
        if (pendingHistory) verifyZeroInteractions(metricsRepository);
        verifyNever(() => expenses.get(pageLink: '?page[after]=late'));
      },
    );
  }
}
