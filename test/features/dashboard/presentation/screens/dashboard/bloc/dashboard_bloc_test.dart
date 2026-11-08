import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';

import 'package:cordato/features/dashboard/presentation/enums/dashboard_phase_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_state.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';
import '../../../../../../support/expense/mocks/expense_repository_mock.dart';
import '../../../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  late DashboardBloc bloc;
  late UserRepositoryMock users;
  late ExpenseRepositoryMock expenses;
  late MetricsRepositoryMock metricsRepository;
  late List<StreamSubscription<DashboardState>> subscriptions;
  final today = DateTime(2026, 10, 19, 16, 30);
  const profile = UserEntity(id: 'user', name: 'Gabriel', email: 'a@b.com');

  ExpensePageEntity page(List<DateTime> dates, {int? nextPage}) =>
      ExpensePageEntity(
        nextPage: nextPage,
        items: [
          for (final date in dates)
            ExpenseEntity(
              id: date.toIso8601String(),
              category: .food,
              occurredOn: date,
              description: 'Despesa',
              cents: .create(cents: 100),
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
  Future<ExpensePageEntity> history() =>
      expenses.get(pageSize: 1, sort: 'occurred_on');

  DashboardBloc create({DateTime? date}) {
    final bloc = DashboardBloc(
      userRepository: users,
      expenseRepository: expenses,
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

  void stubRecent(Future<ExpensePageEntity> Function() response) {
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
    metricsRepository = MetricsRepositoryMock();
    when(() => users.getById()).thenAnswer((_) async => profile);
    when(history).thenAnswer((_) async => page([DateTime(2024, 1)]));
    stubRecent(() async => page([]));
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

  group('Initial state and coordinated loading', () {
    test(
      'starts in the current civil month without querying before opening',
      () async {
        await bloc.close();
        final now = DateTime.now();
        bloc = DashboardBloc(
          userRepository: users,
          expenseRepository: expenses,
          metricsRepository: metricsRepository,
        );
        expect(bloc.state.currentMonth, DateTime(now.year, now.month));
        expect(bloc.state.selectedMonth, DateTime(now.year, now.month));
        expect(bloc.state.phase, DashboardPhaseEnum.loading);
        verifyZeroInteractions(users);
        verifyZeroInteractions(expenses);
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
        final pendingHistory = Completer<ExpensePageEntity>();
        when(() => users.getById()).thenAnswer((_) => pendingUser.future);
        when(history).thenAnswer((_) => pendingHistory.future);
        await send(DashboardOpened());
        verify(() => users.getById()).called(1);
        verify(history).called(1);
        verifyZeroInteractions(metricsRepository);
        pendingUser.complete(profile);
        await flush();
        expect(bloc.state.user, isNull);
        verifyZeroInteractions(metricsRepository);
        pendingHistory.complete(page([]));
        await flush();
        expect(bloc.state.phase, DashboardPhaseEnum.ready);
      },
    );

    test(
      'does not publish completed sections while another section is pending',
      () async {
        final states = recordStates();
        final pendingMetrics = Completer<ExpenseMetricsEntity>();
        final pendingExpenses = Completer<ExpensePageEntity>();
        stubMetrics(() => pendingMetrics.future);
        stubRecent(() => pendingExpenses.future);
        await send(DashboardOpened());
        pendingMetrics.complete(totals(DateTime(2026, 10)));
        await flush();
        expect(states.length, 1);
        expect(bloc.state.phase, DashboardPhaseEnum.loading);
        expect(bloc.state.user, isNull);
        expect(bloc.state.metrics, isNull);
        expect(bloc.state.expenses, isNull);
        pendingExpenses.complete(page([]));
        await flush();
        expect(states.length, 2);
        expect(bloc.state.phase, DashboardPhaseEnum.ready);
      },
    );
  });

  group('Empty dashboard context', () {
    test(
      'successful empty history enables the first-expense message',
      () async {
        when(history).thenAnswer((_) async => page([]));

        final ready = bloc.stream.firstWhere((state) => state.phase == .ready);
        bloc.add(DashboardOpened());
        final state = await ready;

        expect(state.isEmpty, isTrue);
        expect(state.hasNoExpenseHistory, isTrue);
      },
    );

    test('an empty month with history is not first use', () async {
      final ready = bloc.stream.firstWhere((state) => state.phase == .ready);
      bloc.add(DashboardOpened());
      final state = await ready;

      expect(state.isEmpty, isTrue);
      expect(state.hasNoExpenseHistory, isFalse);
      expect(state.firstMonth, DateTime(2024, 1));
    });

    test('failed history does not fabricate first use', () async {
      when(history).thenThrow(ExpenseException(errors: .unknown()));

      final ready = bloc.stream.firstWhere((state) => state.phase == .ready);
      bloc.add(DashboardOpened());
      final state = await ready;

      expect(state.isEmpty, isTrue);
      expect(state.hasNoExpenseHistory, isFalse);
      expect(state.firstMonth, isNull);
    });

    test('profile refresh preserves confirmed empty history', () async {
      when(history).thenAnswer((_) async => page([]));
      final opened = bloc.stream.firstWhere((state) => state.phase == .ready);
      bloc.add(DashboardOpened());
      await opened;

      final refreshed = bloc.stream.firstWhere(
        (state) => state.phase == .ready,
      );
      bloc.add(DashboardUserRequested());
      final state = await refreshed;

      expect(state.isEmpty, isTrue);
      expect(state.hasNoExpenseHistory, isTrue);
      verify(history).called(1);
    });
  });

  group('Section and auxiliary failures', () {
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
      for (final section in ['metrics', 'expenses']) {
        test(
          '$section preserves the original typed failure after every section completes with ${errors.errors.length} errors',
          () async {
            final pending = Completer<ExpensePageEntity>();
            stubRecent(() => pending.future);
            switch (section) {
              case 'metrics':
                stubMetrics(() async => throw MetricsException(errors: errors));
              case 'expenses':
                stubMetrics(() async => totals(DateTime(2026, 10)));
            }
            final states = recordStates();
            await send(DashboardOpened());
            expect(bloc.state.phase, DashboardPhaseEnum.loading);
            if (section == 'expenses') {
              pending.completeError(ExpenseException(errors: errors));
            } else {
              pending.complete(page([]));
            }
            await flush();
            expect(states.map((state) => state.phase), [
              DashboardPhaseEnum.loading,
              DashboardPhaseEnum.failure,
            ]);
            expect(bloc.state.metrics, isNull);
            expect(bloc.state.canRetry, isTrue);
            expect(bloc.state.financialError, same(errors));
          },
        );
      }

      test(
        'User failure preserves ${errors.errors.length} errors and fails the whole Dashboard',
        () async {
          final pendingHistory = Completer<ExpensePageEntity>();
          when(() => users.getById())
              .thenAnswer((_) async => throw UserException(errors: errors));
          when(history).thenAnswer((_) => pendingHistory.future);
          final states = recordStates();

          await send(DashboardOpened());
          expect(bloc.state.phase, DashboardPhaseEnum.loading);
          pendingHistory.complete(page([]));
          await flush();

          expect(states.map((state) => state.phase), [
            DashboardPhaseEnum.loading,
            DashboardPhaseEnum.failure,
          ]);
          expect(bloc.state.user, isNull);
          expect(bloc.state.metrics, isNull);
          expect(bloc.state.expenses, isNull);
          expect(bloc.state.canRetry, isTrue);
          expect(bloc.state.financialError, same(errors));
          verify(history).called(1);
          verify(() => users.getById()).called(1);
          verifyNoMoreInteractions(expenses);
          verifyZeroInteractions(metricsRepository);
        },
      );
    }

    test('unexpected section exceptions become unknown errors without partial publication', () async {
      stubMetrics(() => throw StateError('unexpected'));
      await send(DashboardOpened());
      expect(bloc.state.phase, DashboardPhaseEnum.failure);
      expect(
        bloc.state.financialError!.errors.first.title,
        'Erro desconhecido',
      );
      verify(
        () => expenses.get(
          pageSize: 6,
          from: DateTime(2026, 10),
          to: DateTime(2026, 10, 31),
        ),
      ).called(1);
    });

    for (final unexpected in [false, true]) {
      test(
        'history ${unexpected ? 'unexpected' : 'typed'} failures preserve the existing fallback',
        () async {
          when(history).thenAnswer((_) async {
            if (unexpected) throw StateError('history');
            throw ExpenseException(errors: ErrorsEntity.unknown());
          });
          await send(DashboardOpened());
          expect(bloc.state.phase, DashboardPhaseEnum.ready);
          expect(bloc.state.user, same(profile));
          expect(bloc.state.firstMonth, isNull);
          expect(bloc.state.canGoBack, isFalse);
          expect(bloc.state.financialError, isNull);
        },
      );
    }
  });

  group('Civil periods and history boundaries', () {
    for (final date in [DateTime(2026, 1, 20), DateTime(2024, 3, 10)]) {
      test(
        'loads the complete civil interval across ${date.year}-${date.month}',
        () async {
          await bloc.close();
          when(history).thenAnswer((_) async => page([DateTime(2020)]));
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
          expect(bloc.state.currentMonth, DateTime(date.year, date.month));
          expect(bloc.state.selectedMonth, month);
          verify(
            () => metricsRepository.getExpenses(
              startDate: month,
              endDate: end,
              groupBy: .category,
            ),
          ).called(1);
          verify(() => expenses.get(pageSize: 6, from: month, to: end))
              .called(1);
          verify(() => users.getById()).called(2);
          verify(history).called(2);
        },
      );
    }

    test('blocks future months and months before the first expense', () async {
      when(history).thenAnswer((_) async => page([DateTime(2026, 10)]));
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

    test(
      'blocked events neither cancel nor queue work during loading',
      () async {
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
      },
    );

    test('reads the first historical civil month once and ignores opaque continuations', () async {
      when(history).thenAnswer(
        (_) async => page([DateTime.utc(2000, 2, 29, 23)], nextPage: 2),
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
      when(history).thenAnswer((_) async => page([]));
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
          when(history).thenAnswer((_) async => page(dates));
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
      when(history)
          .thenAnswer((_) async => throw ExpenseException(errors: .unknown()));
      await send(DashboardRefreshRequested());
      expect(bloc.state.selectedMonth, DateTime(2026, 9));
      expect(bloc.state.metrics!.startDate, DateTime(2026, 9));
      expect(bloc.state.canGoBack, isFalse);
      expect(bloc.state.canGoForward, isTrue);
    });
  });

  group('Retry and obsolete loading cycles', () {
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
              () async =>
                  throw MetricsException(errors: ErrorsEntity.unknown()),
            );
          }
          await send(DashboardOpened());
          final pending = Completer<ExpensePageEntity>();
          when(history).thenAnswer((_) => pending.future);
          await send(event);
          when(history).thenAnswer((_) async => page([]));
          stubMetrics(() async => totals(DateTime(2026, 10)));
          await send(DashboardExpensesChanged());
          final ready = bloc.state;
          expect(ready.phase, DashboardPhaseEnum.ready);
          pending.complete(page([DateTime(2000)]));
          await flush();
          expect(bloc.state, same(ready));
        },
      );
    }
  });

  group('Profile refresh and lifecycle', () {
    test('a confirmed profile with an empty name remains valid', () async {
      const unnamed = UserEntity(id: 'user', name: '', email: 'a@b.com');
      when(() => users.getById()).thenAnswer((_) async => unnamed);

      await send(DashboardOpened());

      expect(bloc.state.phase, DashboardPhaseEnum.ready);
      expect(bloc.state.user, same(unnamed));
      expect(bloc.state.user!.name, isEmpty);
      expect(bloc.state.financialError, isNull);
    });

    test(
      'returning from User with ready content reloads only the profile',
      () async {
        await send(DashboardOpened());
        final previous = bloc.state;
        clearInteractions(expenses);
        clearInteractions(metricsRepository);
        final states = recordStates();
        const updatedProfile = UserEntity(
          id: 'user',
          name: 'Gabriel atualizado',
          email: 'a@b.com',
          avatar: 'updated-avatar',
        );
        when(() => users.getById()).thenAnswer((_) async => updatedProfile);
        await send(DashboardUserRequested());
        expect(states.map((state) => state.phase), [
          DashboardPhaseEnum.loading,
          DashboardPhaseEnum.ready,
        ]);
        expect(states.first.metrics, isNull);
        expect(bloc.state.user, same(updatedProfile));
        expect(bloc.state.metrics, same(previous.metrics));
        expect(bloc.state.expenses, same(previous.expenses));
        expect(bloc.state.firstMonth, previous.firstMonth);
        verifyZeroInteractions(expenses);
        verifyZeroInteractions(metricsRepository);
      },
    );

    for (final errors in [
      const ErrorsEntity(errors: []),
      const ErrorsEntity(
        errors: [
          ErrorEntity(
            title: 'Perfil indisponível',
            pointer: '/name',
            parameter: 'profile',
          ),
        ],
      ),
    ]) {
      test(
        'profile refresh failure preserves ${errors.errors.length} errors and clears all content',
        () async {
          await send(DashboardOpened());
          await send(DashboardPreviousMonthRequested());
          clearInteractions(expenses);
          clearInteractions(metricsRepository);
          final states = recordStates();
          when(() => users.getById())
              .thenAnswer((_) async => throw UserException(errors: errors));

          await send(DashboardUserRequested());

          expect(states.map((state) => state.phase), [
            DashboardPhaseEnum.loading,
            DashboardPhaseEnum.failure,
          ]);
          expect(bloc.state.user, isNull);
          expect(bloc.state.metrics, isNull);
          expect(bloc.state.expenses, isNull);
          expect(bloc.state.canRetry, isTrue);
          expect(bloc.state.financialError, same(errors));
          expect(bloc.state.selectedMonth, DateTime(2026, 9));
          verifyZeroInteractions(expenses);
          verifyZeroInteractions(metricsRepository);
        },
      );
    }

    test(
      'manual retry after a profile failure reloads the complete Dashboard',
      () async {
        await send(DashboardOpened());
        when(() => users.getById())
            .thenAnswer((_) async => throw UserException(errors: .unknown()));
        await send(DashboardUserRequested());
        expect(bloc.state.phase, DashboardPhaseEnum.failure);
        final states = recordStates();
        when(() => users.getById()).thenAnswer((_) async => profile);

        await send(DashboardRetryRequested());

        expect(states.map((state) => state.phase), [
          DashboardPhaseEnum.loading,
          DashboardPhaseEnum.ready,
        ]);
        expect(bloc.state.user, same(profile));
        expect(bloc.state.financialError, isNull);
        verify(() => users.getById()).called(3);
        verify(history).called(2);
        verify(
          () => metricsRepository.getExpenses(
            startDate: DateTime(2026, 10),
            endDate: DateTime(2026, 10, 31),
            groupBy: .category,
          ),
        ).called(2);
      },
    );

    for (final event in <DashboardEvent>[
      DashboardOpened(),
      DashboardUserRequested(),
    ]) {
      const missingIdentity = MissingAuthenticatedUserException();
      blocTest<DashboardBloc, DashboardState>(
        '${event.runtimeType} preserves shared identity errors without reporting',
        setUp: () => bloc.close(),
        build: () {
          when(() => users.getById())
              .thenAnswer((_) async => throw missingIdentity);
          return bloc = create();
        },
        seed: () => DashboardState(
          currentMonth: today,
          phase: event is DashboardUserRequested
              ? DashboardPhaseEnum.ready
              : DashboardPhaseEnum.loading,
        ),
        act: (bloc) => bloc.add(event),
        expect: () => [
          isA<DashboardState>().having(
            (state) => state.isLoading,
            'loading',
            isTrue,
          ),
          isA<DashboardState>()
              .having(
                (state) => state.phase,
                'phase',
                DashboardPhaseEnum.failure,
              )
              .having(
                (state) => state.financialError,
                'errors',
                same(missingIdentity.errors),
              )
              .having((state) => state.user, 'user', isNull)
              .having((state) => state.metrics, 'metrics', isNull)
              .having((state) => state.expenses, 'expenses', isNull),
        ],
        errors: () => isEmpty,
        verify: (_) => verifyZeroInteractions(metricsRepository),
      );

      for (final synchronous in [false, true]) {
        final error = StateError('unexpected profile failure');
        blocTest<DashboardBloc, DashboardState>(
          '${event.runtimeType} reports a ${synchronous ? 'synchronous' : 'asynchronous'} unexpected User failure',
          setUp: () => bloc.close(),
          build: () {
            if (synchronous) {
              when(() => users.getById()).thenThrow(error);
            } else {
              when(() => users.getById()).thenAnswer((_) async => throw error);
            }
            return bloc = create();
          },
          seed: () => DashboardState(
            currentMonth: today,
            phase: event is DashboardUserRequested
                ? DashboardPhaseEnum.ready
                : DashboardPhaseEnum.loading,
          ),
          act: (bloc) => bloc.add(event),
          expect: () => [
            isA<DashboardState>().having(
              (state) => state.isLoading,
              'loading',
              isTrue,
            ),
            isA<DashboardState>()
                .having(
                  (state) => state.phase,
                  'phase',
                  DashboardPhaseEnum.failure,
                )
                .having(
                  (state) => state.financialError!.errors.first.title,
                  'safe error',
                  'Erro desconhecido',
                )
                .having((state) => state.user, 'user', isNull)
                .having((state) => state.metrics, 'metrics', isNull)
                .having((state) => state.expenses, 'expenses', isNull),
          ],
          errors: () => [same(error)],
          verify: (_) => verifyZeroInteractions(metricsRepository),
        );
      }
    }

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
      verify(
        () => metricsRepository.getExpenses(
          startDate: DateTime(2026, 10),
          endDate: DateTime(2026, 10, 31),
          groupBy: .category,
        ),
      ).called(1);
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
          final oldHistory = Completer<ExpensePageEntity>();
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
            oldHistory.complete(page([DateTime(2000)], nextPage: 2));
          } else {
            oldMetrics.completeError(StateError('late metrics'));
          }
          await flush();
          expect(bloc.state, same(closed));
          if (pendingHistory) verifyZeroInteractions(metricsRepository);
          verifyNever(() => expenses.get(page: 2));
        },
      );
    }
  });
}
