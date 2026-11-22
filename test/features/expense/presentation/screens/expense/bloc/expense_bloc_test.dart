import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  final expense = ExpenseEntity(
    id: '1',
    description: ' Original ',
    cents: .create(cents: 1234),
    occurredOn: DateTime(2026, 9, 3),
    category: .food,
  );
  const submitted = ExpenseSubmittedEvent(
    cents: 1234,
    description: ' Original ',
  );
  setUp(() {
    repository = ExpenseRepositoryMock();
    when(() => repository.create(cents: 1234, description: ' Original '))
        .thenAnswer((_) async => expense);
    when(() => repository.getById(id: '1')).thenAnswer((_) async => expense);
    when(() => repository.update(id: '1', cents: 2000))
        .thenAnswer((_) async => expense);
  });

  group('Initial state, creation and editing', () {
    test('submission carries the selected category without normalization', () {
      const event = ExpenseSubmittedEvent(
        cents: 1234,
        description: ' Original ',
        category: .transport,
      );

      expect(event.category, same(ExpenseCategoryEnum.transport));
      expect(event.description, ' Original ');
      expect(submitted.category, isNull);
    });

    blocTest<ExpenseBloc, ExpenseState>(
      'delegates the selected creation category and keeps the confirmed API result',
      build: () {
        when(
          () => repository.create(
            cents: 1234,
            description: ' Original ',
            category: .transport,
          ),
        ).thenAnswer((_) async => expense);
        return ExpenseBloc(repository: repository);
      },
      act: (bloc) => bloc.add(
        const ExpenseSubmittedEvent(
          cents: 1234,
          description: ' Original ',
          category: .transport,
        ),
      ),
      expect: () => [
        isA<ExpenseSubmitting>(),
        isA<ExpenseSuccess>().having(
          (state) => state.expense,
          'confirmed API entity, not a locally recategorized entity',
          same(expense),
        ),
      ],
      verify: (_) => verify(
        () => repository.create(
          cents: 1234,
          description: ' Original ',
          category: .transport,
        ),
      ).called(1),
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'delegates a category-only edit and keeps the confirmed API result',
      build: () {
        when(() => repository.update(id: '1', category: .transport))
            .thenAnswer((_) async => expense);
        return ExpenseBloc(repository: repository);
      },
      seed: () => ExpenseReady(expense: expense),
      act: (bloc) =>
          bloc.add(const ExpenseSubmittedEvent(id: '1', category: .transport)),
      expect: () => [
        isA<ExpenseSubmitting>(),
        isA<ExpenseSuccess>()
            .having((state) => state.isEditing, 'editing', true)
            .having((state) => state.expense, 'API entity', same(expense)),
      ],
      verify: (_) =>
          verify(() => repository.update(id: '1', category: .transport))
              .called(1),
    );

    test('starts idle without a request', () async {
      final bloc = ExpenseBloc(repository: repository);
      expect(bloc.state, isA<ExpenseInitial>());
      expect(bloc.state.canSubmit, isTrue);
      verifyZeroInteractions(repository);
      await bloc.close();
    });

    blocTest<ExpenseBloc, ExpenseState>(
      'defaults missing creation category to other and blocks after success',
      build: () => ExpenseBloc(repository: repository),
      act: (bloc) async {
        final done = bloc.stream.firstWhere((s) => s is ExpenseSuccess);
        bloc.add(submitted);
        await done;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ExpenseSubmitting>(),
        isA<ExpenseSuccess>()
            .having((s) => s.expense, 'API entity', same(expense))
            .having((s) => s.canSubmit, 'blocked', false),
      ],
      verify: (_) => verify(
        () => repository.create(
          cents: 1234,
          description: ' Original ',
          category: .other,
        ),
      ).called(1),
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'delegates an explicit edit back to other',
      build: () {
        when(() => repository.update(id: '1', category: .other))
            .thenAnswer((_) async => expense);
        return ExpenseBloc(repository: repository);
      },
      seed: () => ExpenseReady(expense: expense),
      act: (bloc) =>
          bloc.add(const ExpenseSubmittedEvent(id: '1', category: .other)),
      expect: () => [isA<ExpenseSubmitting>(), isA<ExpenseSuccess>()],
      verify: (_) =>
          verify(() => repository.update(id: '1', category: .other)).called(1),
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'loads and updates only supplied attributes',
      build: () => ExpenseBloc(repository: repository),
      act: (bloc) async {
        final ready = bloc.stream.firstWhere((s) => s is ExpenseReady);
        bloc.add(const ExpenseRequestedEvent(id: '1'));
        await ready;
        bloc.add(const ExpenseSubmittedEvent(id: '1', cents: 2000));
      },
      expect: () => [
        isA<ExpenseLoading>(),
        isA<ExpenseReady>(),
        isA<ExpenseSubmitting>().having(
          (s) => s.expense,
          'confirmed entity',
          same(expense),
        ),
        isA<ExpenseSuccess>().having((s) => s.isEditing, 'edit', true),
      ],
      verify: (_) =>
          verify(() => repository.update(id: '1', cents: 2000)).called(1),
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'continuous creation permits another intentional submission',
      build: () => ExpenseBloc(repository: repository),
      act: (bloc) async {
        final done = bloc.stream.firstWhere((s) => s is ExpenseSuccess);
        bloc.add(
          const ExpenseSubmittedEvent(
            cents: 1234,
            description: ' Original ',
            keepFormOpen: true,
          ),
        );
        await done;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ExpenseSubmitting>(),
        isA<ExpenseSuccess>().having((s) => s.canSubmit, 'continue', true),
        isA<ExpenseSubmitting>(),
        isA<ExpenseSuccess>(),
      ],
    );
  });

  group('Failure handling', () {
    final missingExpense = ExpenseException(
      errors: const ErrorsEntity(
        errors: [ErrorEntity(code: 'expense_not_found')],
      ),
    );
    blocTest<ExpenseBloc, ExpenseState>(
      'preserves local not-found errors and permits a manual retry',
      build: () {
        when(() => repository.create(cents: 1234, description: ' Original '))
            .thenThrow(missingExpense);
        return ExpenseBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ExpenseSubmissionFailure,
        );
        bloc.add(submitted);
        await failed;
        when(() => repository.create(cents: 1234, description: ' Original '))
            .thenAnswer((_) async => expense);
        bloc.add(submitted);
      },
      expect: () => [
        isA<ExpenseSubmitting>(),
        isA<ExpenseSubmissionFailure>()
            .having(
              (state) => state.errors,
              'errors',
              same(missingExpense.errors),
            )
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
        isA<ExpenseSubmitting>(),
        isA<ExpenseSuccess>(),
      ],
      errors: () => isEmpty,
    );

    for (final errors in [
      const ErrorsEntity(errors: []),
      ErrorsEntity.unknown(),
    ]) {
      blocTest<ExpenseBloc, ExpenseState>(
        'preserves expected errors and allows manual retry ${errors.errors.length}',
        build: () {
          when(() => repository.create(cents: 1234, description: ' Original '))
              .thenThrow(ExpenseException(errors: errors));
          return ExpenseBloc(repository: repository);
        },
        act: (bloc) async {
          final failed = bloc.stream.firstWhere(
            (s) => s is ExpenseSubmissionFailure,
          );
          bloc.add(submitted);
          await failed;
          when(() => repository.create(cents: 1234, description: ' Original '))
              .thenAnswer((_) async => expense);
          bloc.add(submitted);
        },
        expect: () => [
          isA<ExpenseSubmitting>(),
          isA<ExpenseSubmissionFailure>().having(
            (s) => s.errors,
            'identity',
            same(errors),
          ),
          isA<ExpenseSubmitting>(),
          isA<ExpenseSuccess>(),
        ],
        errors: () => [],
      );
      blocTest<ExpenseBloc, ExpenseState>(
        'preserves load errors ${errors.errors.length}',
        build: () {
          when(() => repository.getById(id: '1'))
              .thenThrow(ExpenseException(errors: errors));
          return ExpenseBloc(repository: repository);
        },
        act: (bloc) => bloc.add(const ExpenseRequestedEvent(id: '1')),
        expect: () => [
          isA<ExpenseLoading>(),
          isA<ExpenseLoadFailure>().having(
            (s) => s.errors,
            'identity',
            same(errors),
          ),
        ],
      );
    }

    final unexpected = StateError('private');
    blocTest<ExpenseBloc, ExpenseState>(
      'reports unexpected failure with safe fallback',
      build: () {
        when(() => repository.create(cents: 1234, description: ' Original '))
            .thenThrow(unexpected);
        return ExpenseBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ExpenseSubmitting>(),
        isA<ExpenseSubmissionFailure>().having(
          (s) => s.errors.errors.toString(),
          'safe',
          isNot(contains('private')),
        ),
      ],
      errors: () => [same(unexpected)],
    );
  });

  group('Concurrency and lifecycle', () {
    test('drops concurrent submissions without queueing', () async {
      final pending = Completer<ExpenseEntity>();
      final entered = Completer<void>();
      when(() => repository.create(cents: 1234, description: ' Original '))
          .thenAnswer((_) {
            entered.complete();
            return pending.future;
          });
      final bloc = ExpenseBloc(repository: repository);
      bloc.add(submitted);
      await entered.future;
      bloc.add(submitted);
      bloc.add(const ExpenseSubmittedEvent(cents: 9999, description: 'Other'));
      await Future<void>(() {});
      final done = bloc.stream.firstWhere((s) => s is ExpenseSuccess);
      pending.complete(expense);
      await done;
      await bloc.close();
      verify(() => repository.create(cents: 1234, description: ' Original '))
          .called(1);
      verifyNever(() => repository.create(cents: 9999, description: 'Other'));
    });

    for (final failure in [
      null,
      ExpenseException(errors: .unknown()),
      StateError('late'),
    ]) {
      blocTest<ExpenseBloc, ExpenseState>(
        'close suppresses late result $failure',
        build: () => ExpenseBloc(repository: repository),
        act: (bloc) async {
          final pending = Completer<ExpenseEntity>();
          final entered = Completer<void>();
          when(() => repository.create(cents: 1234, description: ' Original '))
              .thenAnswer((_) {
                entered.complete();
                return pending.future;
              });
          bloc.add(submitted);
          await entered.future;
          final closed = bloc.close();
          if (failure == null) {
            pending.complete(expense);
          } else {
            pending.completeError(failure);
          }
          await closed;
        },
        expect: () => [isA<ExpenseSubmitting>()],
        errors: () => [],
      );
    }

    test('latest ID wins without publishing obsolete load errors', () async {
      final pending = Completer<ExpenseEntity>();
      final entered = Completer<void>();
      when(() => repository.getById(id: 'old')).thenAnswer((_) {
        entered.complete();
        return pending.future;
      });
      final bloc = ExpenseBloc(repository: repository);
      bloc.add(const ExpenseRequestedEvent(id: 'old'));
      await entered.future;
      final done = bloc.stream.firstWhere((s) => s is ExpenseReady);
      bloc.add(const ExpenseRequestedEvent(id: '1'));
      await done;
      pending.completeError(StateError('obsolete'));
      await bloc.close();
      expect(bloc.state.expense, same(expense));
    });

    test(
      'new form context can submit while an obsolete mutation remains pending',
      () async {
        final old = Completer<ExpenseEntity>();
        final entered = Completer<void>();
        when(() => repository.create(cents: 1234, description: ' Original '))
            .thenAnswer((_) {
              entered.complete();
              return old.future;
            });
        final bloc = ExpenseBloc(repository: repository);
        bloc.add(submitted);
        await entered.future;
        final ready = bloc.stream.firstWhere((state) => state is ExpenseReady);
        bloc.add(const ExpenseRequestedEvent(id: '1'));
        await ready;
        final done = bloc.stream.firstWhere((state) => state is ExpenseSuccess);
        bloc.add(const ExpenseSubmittedEvent(id: '1', cents: 2000));
        await done;
        expect((bloc.state as ExpenseSuccess).isEditing, isTrue);
        old.completeError(StateError('obsolete mutation'));
        await bloc.close();
        expect(bloc.state, isA<ExpenseSuccess>());
        verify(() => repository.update(id: '1', cents: 2000)).called(1);
      },
    );
  });
}
