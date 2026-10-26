import 'dart:async';

import 'package:bloc_test/bloc_test.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
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
  );

  setUp(() {
    repository = ExpenseRepositoryMock();
  });

  Future<void> close(WidgetTester tester) async {
    await tester.runAsync(bloc.close);
  }

  testWidgets(
    'initial state, minimum and exact debounce without normalization',
    (tester) async {
      bloc = ExpenseSuggestionsBloc(repository: repository);
      expect(bloc.state, isA<ExpenseSuggestionsIdle>());
      bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Me'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(() => repository.suggestions(query: any(named: 'query')));
      when(() => repository.suggestions(query: ' Alu '))
          .thenAnswer((_) async => [rent]);
      bloc.add(const ExpenseSuggestionsRequested(revision: 2, query: ' Alu '));
      await tester.pump();
      expect(bloc.state, isA<ExpenseSuggestionsLoading>());
      await tester.pump(const Duration(milliseconds: 299));
      verifyNever(() => repository.suggestions(query: any(named: 'query')));
      await tester.pump(const Duration(milliseconds: 1));
      expect((bloc.state as ExpenseSuggestionsSuccess).suggestions, [rent]);
      expect(
        () => (bloc.state as ExpenseSuggestionsSuccess).suggestions.clear(),
        throwsUnsupportedError,
      );
      await close(tester);
    },
  );

  testWidgets('new input and invalidation cancel debounce before HTTP', (
    tester,
  ) async {
    bloc = ExpenseSuggestionsBloc(repository: repository);
    bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Mer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    bloc.add(const ExpenseSuggestionsInvalidated(revision: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(bloc.state, isA<ExpenseSuggestionsIdle>());
    verifyNever(() => repository.suggestions(query: any(named: 'query')));
    await close(tester);
  });

  testWidgets('old request completing during new debounce cannot publish', (
    tester,
  ) async {
    bloc = ExpenseSuggestionsBloc(repository: repository);
    final old = Completer<List<ExpenseSuggestionEntity>>();
    when(() => repository.suggestions(query: 'Mer'))
        .thenAnswer((_) => old.future);
    when(() => repository.suggestions(query: 'Alu'))
        .thenAnswer((_) async => [rent]);
    bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Mer'));
    await tester.pump();
    await tester.pump(ExpenseSuggestionsBloc.debounce);
    bloc.add(const ExpenseSuggestionsRequested(revision: 2, query: 'Alu'));
    await tester.pump();
    old.complete([]);
    await tester.pump();
    expect(bloc.state, isA<ExpenseSuggestionsLoading>());
    expect(bloc.state.revision, 2);
    await tester.pump(ExpenseSuggestionsBloc.debounce);
    expect((bloc.state as ExpenseSuggestionsSuccess).suggestions, [rent]);
    await close(tester);
  });

  testWidgets('expected failure preserves errors and new input retries', (
    tester,
  ) async {
    bloc = ExpenseSuggestionsBloc(repository: repository);
    const errors = ErrorsEntity(errors: []);
    when(() => repository.suggestions(query: 'Alu'))
        .thenThrow(ExpenseException(errors: errors));
    bloc.add(const ExpenseSuggestionsRequested(revision: 1, query: 'Alu'));
    await tester.pump();
    await tester.pump(ExpenseSuggestionsBloc.debounce);
    expect((bloc.state as ExpenseSuggestionsFailure).errors, same(errors));
    when(() => repository.suggestions(query: 'Alu'))
        .thenAnswer((_) async => []);
    bloc.add(const ExpenseSuggestionsRequested(revision: 2, query: 'Alu'));
    await tester.pump();
    await tester.pump(ExpenseSuggestionsBloc.debounce);
    expect(bloc.state, isA<ExpenseSuggestionsSuccess>());
    await close(tester);
  });

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
}
