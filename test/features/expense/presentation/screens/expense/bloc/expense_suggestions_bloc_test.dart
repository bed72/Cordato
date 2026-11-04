import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_state.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  late ExpenseSuggestionsBloc bloc;
  final rent = ExpenseSuggestionEntity(
    id: 'rent',
    description: 'Aluguel',
    cents: 160000,
    category: .housing,
  );

  setUp(() {
    repository = ExpenseRepositoryMock();
  });

  group('Input and debounce', () {
    test(
      'initial state, minimum and exact debounce without normalization',
      () => fakeAsync((async) {
        bloc = ExpenseSuggestionsBloc(repository: repository);
        addTearDown(bloc.close);
        expect(bloc.state, isA<ExpenseSuggestionsIdle>());
        bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Me'));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        verifyNever(() => repository.suggestions(query: any(named: 'query')));
        when(() => repository.suggestions(query: ' Alu '))
            .thenAnswer((_) async => [rent]);
        bloc.add(
          const ExpenseSuggestionsRequested(revision: 2, query: ' Alu '),
        );
        async.flushMicrotasks();
        expect(bloc.state, isA<ExpenseSuggestionsLoading>());
        async.elapse(const Duration(milliseconds: 299));
        verifyNever(() => repository.suggestions(query: any(named: 'query')));
        async.elapse(const Duration(milliseconds: 1));
        expect((bloc.state as ExpenseSuggestionsSuccess).suggestions, [rent]);
        expect(
          (bloc.state as ExpenseSuggestionsSuccess).suggestions.single.category,
          ExpenseCategoryEnum.housing,
        );
        expect(
          () => (bloc.state as ExpenseSuggestionsSuccess).suggestions.clear(),
          throwsUnsupportedError,
        );
        expect(async.pendingTimers, isEmpty);
      }),
    );

    test(
      'new input and invalidation cancel debounce before HTTP',
      () => fakeAsync((async) {
        bloc = ExpenseSuggestionsBloc(repository: repository);
        addTearDown(bloc.close);
        bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Mer'));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 299));
        bloc.add(const ExpenseSuggestionsInvalidated(revision: 2));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));
        expect(bloc.state, isA<ExpenseSuggestionsIdle>());
        verifyNever(() => repository.suggestions(query: any(named: 'query')));
        expect(async.pendingTimers, isEmpty);
      }),
    );

    test(
      'old request completing during new debounce cannot publish',
      () => fakeAsync((async) {
        bloc = ExpenseSuggestionsBloc(repository: repository);
        addTearDown(bloc.close);
        final old = Completer<List<ExpenseSuggestionEntity>>();
        when(() => repository.suggestions(query: 'Mer'))
            .thenAnswer((_) => old.future);
        when(() => repository.suggestions(query: 'Alu'))
            .thenAnswer((_) async => [rent]);
        bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Mer'));
        async.flushMicrotasks();
        async.elapse(ExpenseSuggestionsBloc.debounce);
        bloc.add(const ExpenseSuggestionsRequested(revision: 2, query: 'Alu'));
        async.flushMicrotasks();
        old.complete([]);
        async.flushMicrotasks();
        expect(bloc.state, isA<ExpenseSuggestionsLoading>());
        expect(bloc.state.revision, 2);
        async.elapse(ExpenseSuggestionsBloc.debounce);
        expect((bloc.state as ExpenseSuggestionsSuccess).suggestions, [rent]);
        expect(async.pendingTimers, isEmpty);
      }),
    );
  });

  group('Failures and lifecycle', () {
    test(
      'expected failure preserves errors and new input retries',
      () => fakeAsync((async) {
        bloc = ExpenseSuggestionsBloc(repository: repository);
        addTearDown(bloc.close);
        const errors = ErrorsEntity(errors: []);
        when(() => repository.suggestions(query: 'Alu'))
            .thenThrow(ExpenseException(errors: errors));
        bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Alu'));
        async.flushMicrotasks();
        async.elapse(ExpenseSuggestionsBloc.debounce);
        expect((bloc.state as ExpenseSuggestionsFailure).errors, same(errors));
        when(() => repository.suggestions(query: 'Alu'))
            .thenAnswer((_) async => []);
        bloc.add(const ExpenseSuggestionsRequested(revision: 2, query: 'Alu'));
        async.flushMicrotasks();
        async.elapse(ExpenseSuggestionsBloc.debounce);
        expect(bloc.state, isA<ExpenseSuggestionsSuccess>());
        expect(async.pendingTimers, isEmpty);
      }),
    );

    test('close prevents pending result from publishing', () async {
      bloc = ExpenseSuggestionsBloc(repository: repository);
      final pending = Completer<List<ExpenseSuggestionEntity>>();
      final called = Completer<void>();
      when(() => repository.suggestions(query: 'Alu')).thenAnswer((_) {
        called.complete();
        return pending.future;
      });
      bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Alu'));
      await called.future;
      final closing = bloc.close();
      pending.complete([rent]);
      await closing;
      expect(bloc.state, isA<ExpenseSuggestionsLoading>());
    });

    final unexpected = StateError('unexpected');
    blocTest<ExpenseSuggestionsBloc, ExpenseSuggestionsState>(
      'unexpected failures use fallback and report original error',
      build: () {
        when(() => repository.suggestions(query: 'Mer')).thenThrow(unexpected);
        return ExpenseSuggestionsBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ExpenseSuggestionsFailure,
        );
        bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Mer'));
        await failed;
      },
      expect: () => [
        isA<ExpenseSuggestionsLoading>(),
        isA<ExpenseSuggestionsFailure>(),
      ],
      errors: () => [same(unexpected)],
    );
  });
}
