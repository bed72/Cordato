import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_event.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  final first = ExpenseEntity(
    id: '1',
    description: 'First',
    cents: .create(cents: 100),
    occurredOn: DateTime(2026, 9, 3),
    category: .food,
  );
  final second = ExpenseEntity(
    id: '2',
    description: 'Second',
    cents: .create(cents: 200),
    occurredOn: DateTime(2026, 9, 2),
    category: .transport,
  );
  ExpensePageEntity page(List<ExpenseEntity> items, {String? next}) =>
      ExpensePageEntity(items: items, next: next, prev: null);
  setUp(() {
    repository = ExpenseRepositoryMock();
    when(() => repository.get(pageSize: 20))
        .thenAnswer((_) async => page([first], next: '?page=2'));
    when(() => repository.get(pageSize: 20, pageLink: '?page=2'))
        .thenAnswer((_) async => page([first, second]));
    when(() => repository.delete(id: '1')).thenAnswer((_) async {});
  });
  Future<void> load(ExpensesBloc bloc) async {
    final ready = bloc.stream.firstWhere((s) => s is ExpensesReady);
    bloc.add(const ExpensesRequestedEvent());
    await ready;
  }

  test('starts idle and snapshots are immutable', () async {
    final bloc = ExpensesBloc(repository: repository);
    expect(bloc.state, isA<ExpensesInitial>());
    verifyZeroInteractions(repository);
    final source = [first];
    final data = ExpensesData(items: source);
    source.clear();
    expect(data.items.single, same(first));
    expect(() => data.items.clear(), throwsUnsupportedError);
    await bloc.close();
  });

  blocTest<ExpensesBloc, ExpensesState>(
    'paginates using opaque continuation and deduplicates IDs',
    build: () => ExpensesBloc(repository: repository),
    act: (bloc) async {
      await load(bloc);
      bloc.add(const ExpensesNextPageRequestedEvent());
    },
    expect: () => [
      isA<ExpensesLoading>(),
      isA<ExpensesReady>(),
      isA<ExpensesLoading>().having((s) => s.refresh, 'append', false),
      isA<ExpensesReady>()
          .having((s) => s.data.items, 'merged', [first, second])
          .having((s) => s.data.next, 'end', isNull),
    ],
    verify: (_) =>
        verify(() => repository.get(pageSize: 20, pageLink: '?page=2'))
            .called(1),
  );

  blocTest<ExpensesBloc, ExpensesState>(
    'deletes only after awaited completion and retains remaining data',
    build: () => ExpensesBloc(repository: repository),
    act: (bloc) async {
      await load(bloc);
      bloc.add(const ExpensesDeleteRequestedEvent(id: '1'));
    },
    expect: () => [
      isA<ExpensesLoading>(),
      isA<ExpensesReady>(),
      isA<ExpensesDeleting>().having(
        (s) => s.data.items,
        'not optimistically removed',
        [first],
      ),
      isA<ExpensesDeleted>().having((s) => s.data.items, 'removed', isEmpty),
    ],
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    ErrorsEntity.unknown(),
  ]) {
    blocTest<ExpensesBloc, ExpensesState>(
      'preserves query error ${errors.errors.length}',
      build: () {
        when(() => repository.get(pageSize: 20))
            .thenThrow(ExpenseException(errors: errors));
        return ExpensesBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const ExpensesRequestedEvent()),
      expect: () => [
        isA<ExpensesLoading>(),
        isA<ExpensesFailure>()
            .having((s) => s.errors, 'identity', same(errors))
            .having((s) => s.refresh, 'retry refresh', true),
      ],
    );
    blocTest<ExpensesBloc, ExpensesState>(
      'preserves delete error and item ${errors.errors.length}',
      build: () {
        when(() => repository.delete(id: '1'))
            .thenThrow(ExpenseException(errors: errors));
        return ExpensesBloc(repository: repository);
      },
      act: (bloc) async {
        await load(bloc);
        bloc.add(const ExpensesDeleteRequestedEvent(id: '1'));
      },
      expect: () => [
        isA<ExpensesLoading>(),
        isA<ExpensesReady>(),
        isA<ExpensesDeleting>(),
        isA<ExpensesDeleteFailure>()
            .having((s) => s.errors, 'identity', same(errors))
            .having((s) => s.data.items, 'preserved', [first]),
      ],
    );
  }

  blocTest<ExpensesBloc, ExpensesState>(
    'page failure retains continuation for manual retry',
    build: () {
      when(() => repository.get(pageSize: 20, pageLink: '?page=2'))
          .thenThrow(ExpenseException(errors: .unknown()));
      return ExpensesBloc(repository: repository);
    },
    act: (bloc) async {
      await load(bloc);
      final failed = bloc.stream.firstWhere((s) => s is ExpensesFailure);
      bloc.add(const ExpensesNextPageRequestedEvent());
      await failed;
      when(() => repository.get(pageSize: 20, pageLink: '?page=2'))
          .thenAnswer((_) async => page([second]));
      bloc.add(const ExpensesNextPageRequestedEvent());
    },
    expect: () => [
      isA<ExpensesLoading>(),
      isA<ExpensesReady>(),
      isA<ExpensesLoading>(),
      isA<ExpensesFailure>()
          .having((s) => s.refresh, 'append retry', false)
          .having((s) => s.data.next, 'link', '?page=2'),
      isA<ExpensesLoading>(),
      isA<ExpensesReady>().having((s) => s.data.items, 'merged', [
        first,
        second,
      ]),
    ],
  );

  test('new filters invalidate pending pagination', () async {
    final pending = Completer<ExpensePageEntity>();
    final entered = Completer<void>();
    when(() => repository.get(pageSize: 20, pageLink: '?page=2'))
        .thenAnswer((_) {
          entered.complete();
          return pending.future;
        });
    when(() => repository.get(pageSize: 20, category: 'transport'))
        .thenAnswer((_) async => page([second]));
    final bloc = ExpensesBloc(repository: repository);
    await load(bloc);
    bloc.add(const ExpensesNextPageRequestedEvent());
    await entered.future;
    final ready = bloc.stream.firstWhere((s) => s is ExpensesReady);
    bloc.add(const ExpensesRequestedEvent(category: 'transport'));
    await ready;
    pending.complete(page([first]));
    await bloc.close();
    expect(bloc.state.data.items, [second]);
    expect(bloc.state.data.category, 'transport');
  });

  test('fresh pagination is not blocked by an obsolete pending page', () async {
    final old = Completer<ExpensePageEntity>();
    final entered = Completer<void>();
    when(() => repository.get(pageSize: 20, pageLink: '?page=2'))
        .thenAnswer((_) {
          entered.complete();
          return old.future;
        });
    when(() => repository.get(pageSize: 20, category: 'transport'))
        .thenAnswer((_) async => page([second], next: '?fresh=2'));
    when(
      () => repository.get(
        pageSize: 20,
        category: 'transport',
        pageLink: '?fresh=2',
      ),
    ).thenAnswer((_) async => page([]));
    final bloc = ExpensesBloc(repository: repository);
    await load(bloc);
    bloc.add(const ExpensesNextPageRequestedEvent());
    await entered.future;
    final fresh = bloc.stream.firstWhere((s) => s is ExpensesReady);
    bloc.add(const ExpensesRequestedEvent(category: 'transport'));
    await fresh;
    final paged = bloc.stream.firstWhere((s) => s is ExpensesReady);
    bloc.add(const ExpensesNextPageRequestedEvent());
    await paged;
    expect(bloc.state.data.next, isNull);
    old.completeError(StateError('obsolete'));
    await bloc.close();
    expect(bloc.state.data.items, [second]);
  });

  test(
    'duplicate next-page requests do not cancel or queue the active page',
    () async {
      final pending = Completer<ExpensePageEntity>();
      final entered = Completer<void>();
      when(() => repository.get(pageSize: 20, pageLink: '?page=2'))
          .thenAnswer((_) {
            entered.complete();
            return pending.future;
          });
      final bloc = ExpensesBloc(repository: repository);
      await load(bloc);
      bloc.add(const ExpensesNextPageRequestedEvent());
      await entered.future;
      bloc.add(const ExpensesNextPageRequestedEvent());
      await Future<void>(() {});
      final ready = bloc.stream.firstWhere((s) => s is ExpensesReady);
      pending.complete(page([second]));
      await ready;
      await bloc.close();
      verify(() => repository.get(pageSize: 20, pageLink: '?page=2')).called(1);
      expect(bloc.state.data.items, [first, second]);
    },
  );

  blocTest<ExpensesBloc, ExpensesState>(
    'delegates civil interval and category unchanged',
    build: () {
      when(
        () => repository.get(
          pageSize: 20,
          from: DateTime.utc(2026, 9, 3),
          to: DateTime.utc(2026, 9, 3),
          category: 'future',
        ),
      ).thenAnswer((_) async => page([]));
      return ExpensesBloc(repository: repository);
    },
    act: (bloc) => bloc.add(
      ExpensesRequestedEvent(
        from: DateTime.utc(2026, 9, 3),
        to: DateTime.utc(2026, 9, 3),
        category: 'future',
      ),
    ),
    expect: () => [
      isA<ExpensesLoading>(),
      isA<ExpensesReady>().having(
        (s) => s.data.items,
        'empty is success',
        isEmpty,
      ),
    ],
    verify: (_) => verify(
      () => repository.get(
        pageSize: 20,
        from: DateTime.utc(2026, 9, 3),
        to: DateTime.utc(2026, 9, 3),
        category: 'future',
      ),
    ).called(1),
  );

  test('deletion drops concurrent mutations, queries and pagination', () async {
    final pending = Completer<void>();
    final entered = Completer<void>();
    when(() => repository.delete(id: '1')).thenAnswer((_) {
      entered.complete();
      return pending.future;
    });
    final bloc = ExpensesBloc(repository: repository);
    await load(bloc);
    bloc.add(const ExpensesDeleteRequestedEvent(id: '1'));
    await entered.future;
    bloc.add(const ExpensesDeleteRequestedEvent(id: '2'));
    bloc.add(const ExpensesRequestedEvent());
    bloc.add(const ExpensesNextPageRequestedEvent());
    await Future<void>(() {});
    final done = bloc.stream.firstWhere((s) => s is ExpensesDeleted);
    pending.complete();
    await done;
    await bloc.close();
    verify(() => repository.delete(id: '1')).called(1);
    verifyNever(() => repository.delete(id: '2'));
    verify(() => repository.get(pageSize: 20)).called(1);
    verifyNever(() => repository.get(pageSize: 20, pageLink: '?page=2'));
  });

  test(
    'latest changed filters wait for a pending mutation before reading',
    () async {
      final pending = Completer<void>();
      final entered = Completer<void>();
      when(() => repository.delete(id: '1')).thenAnswer((_) {
        entered.complete();
        return pending.future;
      });
      when(() => repository.get(pageSize: 20, category: 'transport'))
          .thenAnswer((_) async => page([second]));
      final bloc = ExpensesBloc(repository: repository);
      await load(bloc);
      bloc.add(const ExpensesDeleteRequestedEvent(id: '1'));
      await entered.future;
      bloc.add(const ExpensesRequestedEvent(category: 'food'));
      bloc.add(const ExpensesRequestedEvent(category: 'transport'));
      await Future<void>(() {});
      verifyNever(() => repository.get(pageSize: 20, category: 'transport'));
      final ready = bloc.stream.firstWhere((state) => state is ExpensesReady);
      pending.complete();
      await ready;
      expect(bloc.state.data.category, 'transport');
      expect(bloc.state.data.items, [second]);
      verifyNever(() => repository.get(pageSize: 20, category: 'food'));
      await bloc.close();
    },
  );

  blocTest<ExpensesBloc, ExpensesState>(
    'edited expense outside filters is removed',
    build: () {
      when(() => repository.get(pageSize: 20, category: 'food'))
          .thenAnswer((_) async => page([first]));
      return ExpensesBloc(repository: repository);
    },
    act: (bloc) async {
      final ready = bloc.stream.firstWhere((s) => s is ExpensesReady);
      bloc.add(const ExpensesRequestedEvent(category: 'food'));
      await ready;
      bloc.add(
        ExpensesUpdatedEvent(
          expense: ExpenseEntity(
            id: first.id,
            description: first.description,
            cents: first.cents,
            occurredOn: first.occurredOn,
            category: .transport,
          ),
        ),
      );
    },
    expect: () => [
      isA<ExpensesLoading>(),
      isA<ExpensesReady>(),
      isA<ExpensesReady>().having((s) => s.data.items, 'filtered', isEmpty),
    ],
  );

  for (final deleting in [false, true]) {
    final unexpected = StateError('private');
    blocTest<ExpensesBloc, ExpensesState>(
      'unexpected ${deleting ? 'delete' : 'load'} uses addError and fallback',
      build: () {
        if (deleting) {
          when(() => repository.delete(id: '1')).thenThrow(unexpected);
        } else {
          when(() => repository.get(pageSize: 20)).thenThrow(unexpected);
        }
        return ExpensesBloc(repository: repository);
      },
      act: (bloc) => bloc.add(
        deleting
            ? const ExpensesDeleteRequestedEvent(id: '1')
            : const ExpensesRequestedEvent(),
      ),
      expect: () => deleting
          ? [isA<ExpensesDeleting>(), isA<ExpensesDeleteFailure>()]
          : [isA<ExpensesLoading>(), isA<ExpensesFailure>()],
      errors: () => [same(unexpected)],
    );
    for (final failure in [
      null,
      ExpenseException(errors: .unknown()),
      StateError('late'),
    ]) {
      blocTest<ExpensesBloc, ExpensesState>(
        'close ignores ${deleting ? 'delete' : 'load'} completion $failure',
        build: () => ExpensesBloc(repository: repository),
        act: (bloc) async {
          final pending = Completer<ExpensePageEntity>();
          final deletion = Completer<void>();
          final entered = Completer<void>();
          when(() => repository.get(pageSize: 20)).thenAnswer((_) {
            entered.complete();
            return pending.future;
          });
          when(() => repository.delete(id: '1')).thenAnswer((_) {
            entered.complete();
            return deletion.future;
          });
          bloc.add(
            deleting
                ? const ExpensesDeleteRequestedEvent(id: '1')
                : const ExpensesRequestedEvent(),
          );
          await entered.future;
          final closed = bloc.close();
          if (deleting) {
            if (failure == null) {
              deletion.complete();
            } else {
              deletion.completeError(failure);
            }
          } else {
            if (failure == null) {
              pending.complete(page([]));
            } else {
              pending.completeError(failure);
            }
          }
          await closed;
        },
        expect: () => [
          deleting ? isA<ExpensesDeleting>() : isA<ExpensesLoading>(),
        ],
        errors: () => [],
      );
    }
  }
}
