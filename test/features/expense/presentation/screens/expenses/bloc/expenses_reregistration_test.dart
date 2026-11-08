import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_event.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  final today = DateTime.utc(2026, 11, 8);

  ExpenseEntity sourceExpense({
    ExpenseCategoryEnum category = .other,
    DateTime? occurredOn,
  }) => ExpenseEntity(
    id: 'original',
    category: category,
    description: '  Mercado  ',
    cents: .create(cents: 12345),
    occurredOn: occurredOn ?? DateTime.utc(2026, 9, 12),
  );

  ExpenseEntity createdExpense() => ExpenseEntity(
    id: 'new-record',
    category: .other,
    occurredOn: today,
    description: '  Mercado  ',
    cents: .create(cents: 12345),
  );

  Future<ExpenseEntity> createCall({ExpenseCategoryEnum category = .other}) =>
      repository.create(
        cents: 12345,
        description: '  Mercado  ',
        category: category,
        occurredOn: today,
      );

  ExpensesReady ready() => ExpensesReady(
    data: ExpensesData(items: [sourceExpense()], nextPage: 2, hasLoaded: true),
  );

  ExpensesReregisterRequestedEvent request() =>
      ExpensesReregisterRequestedEvent(
        expense: sourceExpense(),
        confirmedAt: today,
      );

  setUp(() {
    repository = ExpenseRepositoryMock();
    when(() => createCall()).thenAnswer((_) async => createdExpense());
    when(() => repository.get(pageSize: 20)).thenAnswer(
      (_) async => ExpensePageEntity(
        items: [createdExpense(), sourceExpense()],
        nextPage: 2,
      ),
    );
  });

  group('Confirmation civil date', () {
    for (final timestamp in [
      DateTime(2026, 11, 8, 0, 1),
      DateTime(2026, 11, 8, 23, 59),
      DateTime.utc(2026, 11, 8, 23, 59),
    ]) {
      test('keeps civil components at $timestamp', () {
        final event = ExpensesReregisterRequestedEvent(
          expense: sourceExpense(),
          confirmedAt: timestamp,
        );

        expect(event.occurredOn, today);
        expect(event.occurredOn.isUtc, isTrue);
      });
    }

    test('uses confirmation day rather than source day or opening day', () {
      final original = sourceExpense();
      final beforeMidnight = ExpensesReregisterRequestedEvent(
        expense: original,
        confirmedAt: DateTime(2026, 11, 7, 23, 59),
      );
      final afterMidnight = ExpensesReregisterRequestedEvent(
        expense: original,
        confirmedAt: DateTime(2026, 11, 8, 0, 1),
      );

      expect(beforeMidnight.occurredOn, DateTime.utc(2026, 11, 7));
      expect(afterMidnight.occurredOn, today);
      expect(original.occurredOn, DateTime.utc(2026, 9, 12));
    });
  });

  group('Creation and reload', () {
    for (final category in [
      ExpenseCategoryEnum.food,
      ExpenseCategoryEnum.other,
    ]) {
      blocTest<ExpensesBloc, ExpensesState>(
        'copies exact values including category ${category.value}',
        build: () {
          when(() => createCall(category: category))
              .thenAnswer((_) async => createdExpense());
          return ExpensesBloc(repository: repository);
        },
        seed: ready,
        act: (bloc) => bloc.add(
          ExpensesReregisterRequestedEvent(
            expense: sourceExpense(category: category),
            confirmedAt: today,
          ),
        ),
        expect: () => [
          isA<ExpensesReregistering>()
              .having((state) => state.isBusy, 'busy', true)
              .having((state) => state.id, 'source ID', 'original'),
          isA<ExpensesReregistered>()
              .having((state) => state.expense.id, 'new ID', 'new-record')
              .having(
                (state) => state.data.items.single.id,
                'original intact',
                'original',
              ),
          isA<ExpensesLoading>().having(
            (state) => state.refresh,
            'first page',
            true,
          ),
          isA<ExpensesReady>()
              .having((state) => state.data.items.length, 'reloaded items', 2)
              .having((state) => state.data.nextPage, 'continuation', 2),
        ],
        verify: (_) {
          verify(() => createCall(category: category)).called(1);
          verify(() => repository.get(pageSize: 20)).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    blocTest<ExpensesBloc, ExpensesState>(
      'permits another record for an expense already dated today',
      build: () => ExpensesBloc(repository: repository),
      act: (bloc) => bloc.add(
        ExpensesReregisterRequestedEvent(
          expense: sourceExpense(occurredOn: today),
          confirmedAt: today,
        ),
      ),
      expect: () => [
        isA<ExpensesReregistering>(),
        isA<ExpensesReregistered>(),
        isA<ExpensesLoading>(),
        isA<ExpensesReady>(),
      ],
      verify: (_) => verify(() => createCall()).called(1),
    );

    for (final scenario in [
      (month: 9, outsidePeriod: true, expectedCount: 0),
      (month: 11, outsidePeriod: false, expectedCount: 1),
    ]) {
      final from = DateTime.utc(2026, scenario.month);
      final to = DateTime.utc(2026, scenario.month, 30);
      blocTest<ExpensesBloc, ExpensesState>(
        'reloads page one with filters, today outside period=${scenario.outsidePeriod}',
        build: () {
          when(
            () => repository.get(
              pageSize: 20,
              category: 'other',
              from: from,
              to: to,
            ),
          ).thenAnswer(
            (_) async => ExpensePageEntity(
              items: [if (!scenario.outsidePeriod) createdExpense()],
              nextPage: null,
            ),
          );
          return ExpensesBloc(repository: repository);
        },
        seed: () => ExpensesReady(
          data: ExpensesData(
            items: [sourceExpense()],
            nextPage: 4,
            hasLoaded: true,
            category: 'other',
            from: from,
            to: to,
          ),
        ),
        act: (bloc) => bloc.add(request()),
        expect: () => [
          isA<ExpensesReregistering>(),
          isA<ExpensesReregistered>(),
          isA<ExpensesLoading>(),
          isA<ExpensesReady>()
              .having((state) => state.data.category, 'category', 'other')
              .having((state) => state.data.from, 'from', from)
              .having((state) => state.data.to, 'to', to)
              .having(
                (state) => state.data.items.length,
                'server filtered',
                scenario.expectedCount,
              )
              .having(
                (state) => state.data.nextPage,
                'new continuation',
                isNull,
              ),
        ],
        verify: (_) {
          verify(() => createCall()).called(1);
          verify(
            () => repository.get(
              pageSize: 20,
              category: 'other',
              from: from,
              to: to,
            ),
          ).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    blocTest<ExpensesBloc, ExpensesState>(
      'manual retry of failed reload never repeats a confirmed creation',
      build: () {
        when(() => repository.get(pageSize: 20))
            .thenThrow(ExpenseException(errors: .unknown()));
        return ExpensesBloc(repository: repository);
      },
      seed: ready,
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ExpensesFailure,
        );
        bloc.add(request());
        await failed;
        when(() => repository.get(pageSize: 20)).thenAnswer(
          (_) async =>
              ExpensePageEntity(items: [createdExpense()], nextPage: null),
        );
        bloc.add(const ExpensesRequestedEvent());
      },
      expect: () => [
        isA<ExpensesReregistering>(),
        isA<ExpensesReregistered>(),
        isA<ExpensesLoading>(),
        isA<ExpensesFailure>().having(
          (state) => state.refresh,
          'query retry',
          true,
        ),
        isA<ExpensesLoading>(),
        isA<ExpensesReady>(),
      ],
      verify: (_) {
        verify(() => createCall()).called(1);
        verify(() => repository.get(pageSize: 20)).called(2);
      },
    );
  });

  group('Creation failures', () {
    final errors = ErrorsEntity(errors: [ErrorEntity(status: '403')]);
    const missingUser = MissingAuthenticatedUserException();
    for (final scenario in [
      (
        name: 'expense',
        failure: ExpenseException(errors: errors),
        errors: errors,
      ),
      (name: 'missing user', failure: missingUser, errors: missingUser.errors),
    ]) {
      blocTest<ExpensesBloc, ExpensesState>(
        'preserves ${scenario.name} errors and items without retry or telemetry',
        build: () {
          when(() => createCall()).thenThrow(scenario.failure);
          return ExpensesBloc(repository: repository);
        },
        seed: ready,
        act: (bloc) => bloc.add(request()),
        expect: () => [
          isA<ExpensesReregistering>(),
          isA<ExpensesReregisterFailure>()
              .having(
                (state) => state.errors,
                'same errors',
                same(scenario.errors),
              )
              .having((state) => state.isBusy, 'retry enabled', false)
              .having(
                (state) => state.data.items.single.id,
                'original',
                'original',
              )
              .having(
                (state) => state.data.nextPage,
                'continuation preserved',
                2,
              ),
        ],
        errors: () => [],
        verify: (_) {
          verify(() => createCall()).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    final unexpected = StateError('private');
    blocTest<ExpensesBloc, ExpensesState>(
      'unexpected failure uses addError and safe fallback',
      build: () {
        when(() => createCall()).thenThrow(unexpected);
        return ExpensesBloc(repository: repository);
      },
      act: (bloc) => bloc.add(request()),
      expect: () => [
        isA<ExpensesReregistering>(),
        isA<ExpensesReregisterFailure>(),
      ],
      errors: () => [same(unexpected)],
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'allows manual retry after failure',
      build: () {
        when(() => createCall())
            .thenThrow(ExpenseException(errors: .unknown()));
        return ExpensesBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ExpensesReregisterFailure,
        );
        bloc.add(request());
        await failed;
        when(() => createCall()).thenAnswer((_) async => createdExpense());
        bloc.add(request());
      },
      expect: () => [
        isA<ExpensesReregistering>(),
        isA<ExpensesReregisterFailure>(),
        isA<ExpensesReregistering>(),
        isA<ExpensesReregistered>(),
        isA<ExpensesLoading>(),
        isA<ExpensesReady>(),
      ],
      verify: (_) => verify(() => createCall()).called(2),
    );
  });

  group('Concurrency and lifecycle', () {
    blocTest<ExpensesBloc, ExpensesState>(
      'drops duplicate creations, deletion, updates and pagination during POST',
      build: () => ExpensesBloc(repository: repository),
      seed: ready,
      act: (bloc) async {
        final pending = Completer<ExpenseEntity>();
        final entered = Completer<void>();
        when(() => createCall()).thenAnswer((_) {
          entered.complete();
          return pending.future;
        });
        bloc.add(request());
        await entered.future;
        bloc.add(request());
        bloc.add(const ExpensesDeleteRequestedEvent(id: 'original'));
        bloc.add(ExpensesUpdatedEvent(expense: createdExpense()));
        bloc.add(const ExpensesNextPageRequestedEvent());
        await Future<void>(() {});
        expect(bloc.state, isA<ExpensesReregistering>());
        pending.complete(createdExpense());
      },
      expect: () => [
        isA<ExpensesReregistering>(),
        isA<ExpensesReregistered>(),
        isA<ExpensesLoading>(),
        isA<ExpensesReady>(),
      ],
      verify: (_) {
        verify(() => createCall()).called(1);
        verify(() => repository.get(pageSize: 20)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'defers refresh and uses only latest requested filters after POST',
      build: () {
        when(
          () => repository.get(pageSize: 20, category: 'transport'),
        ).thenAnswer((_) async => ExpensePageEntity(items: [], nextPage: null));
        return ExpensesBloc(repository: repository);
      },
      seed: ready,
      act: (bloc) async {
        final pending = Completer<ExpenseEntity>();
        final entered = Completer<void>();
        when(() => createCall()).thenAnswer((_) {
          entered.complete();
          return pending.future;
        });
        bloc.add(request());
        await entered.future;
        bloc.add(const ExpensesRequestedEvent());
        bloc.add(const ExpensesRequestedEvent(category: 'food'));
        bloc.add(const ExpensesRequestedEvent(category: 'transport'));
        await Future<void>(() {});
        verifyNever(() => repository.get(pageSize: 20, category: 'transport'));
        pending.complete(createdExpense());
      },
      expect: () => [
        isA<ExpensesReregistering>(),
        isA<ExpensesReregistered>(),
        isA<ExpensesLoading>(),
        isA<ExpensesReady>().having(
          (state) => state.data.category,
          'latest',
          'transport',
        ),
      ],
      verify: (_) {
        verify(() => createCall()).called(1);
        verify(() => repository.get(pageSize: 20, category: 'transport'))
            .called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    for (final busy in [
      ExpensesLoading(data: ExpensesData(), refresh: true),
      ExpensesDeleting(data: ExpensesData(), id: 'original'),
    ]) {
      blocTest<ExpensesBloc, ExpensesState>(
        'rejects creation during ${busy.runtimeType}',
        build: () => ExpensesBloc(repository: repository),
        seed: () => busy,
        act: (bloc) => bloc.add(request()),
        expect: () => [],
        verify: (_) => verifyZeroInteractions(repository),
      );
    }

    for (final completion in [
      'success',
      'expected failure',
      'unexpected failure',
    ]) {
      blocTest<ExpensesBloc, ExpensesState>(
        'close ignores late $completion without reload or telemetry',
        build: () => ExpensesBloc(repository: repository),
        act: (bloc) async {
          final pending = Completer<ExpenseEntity>();
          final entered = Completer<void>();
          when(() => createCall()).thenAnswer((_) {
            entered.complete();
            return pending.future;
          });
          bloc.add(request());
          await entered.future;
          final closed = bloc.close();
          switch (completion) {
            case 'success':
              pending.complete(createdExpense());
            case 'expected failure':
              pending.completeError(ExpenseException(errors: .unknown()));
            case 'unexpected failure':
              pending.completeError(StateError('late'));
          }
          await closed;
        },
        expect: () => [isA<ExpensesReregistering>()],
        errors: () => [],
        verify: (_) {
          verify(() => createCall()).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    test(
      'obsolete pending page cannot overwrite a later reregistration reload',
      () async {
        final oldPage = Completer<ExpensePageEntity>();
        final entered = Completer<void>();
        when(() => repository.get(pageSize: 20, page: 2)).thenAnswer((_) {
          entered.complete();
          return oldPage.future;
        });
        when(() => repository.get(pageSize: 20, category: 'other')).thenAnswer(
          (_) async =>
              ExpensePageEntity(items: [createdExpense()], nextPage: null),
        );
        final bloc = ExpensesBloc(repository: repository);
        addTearDown(bloc.close);
        Future<void> query(ExpensesEvent event) async {
          final loaded = bloc.stream.firstWhere(
            (state) => state is ExpensesReady,
          );
          bloc.add(event);
          await loaded;
        }

        await query(const ExpensesRequestedEvent());
        bloc.add(const ExpensesNextPageRequestedEvent());
        await entered.future;
        await query(const ExpensesRequestedEvent(category: 'other'));
        await query(request());
        oldPage.complete(
          ExpensePageEntity(items: [sourceExpense()], nextPage: null),
        );
        await bloc.close();

        expect(bloc.state.data.items.single.id, 'new-record');
        expect(bloc.state.data.category, 'other');
        verify(() => createCall()).called(1);
      },
    );
  });
}
