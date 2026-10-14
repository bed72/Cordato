import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';

import '../../../../support/insight/mocks/insight_repository_mock.dart';

void main() {
  late GetInsightsCommand command;
  late List<InsightEntity> insights;
  late InsightRepositoryMock repository;
  void onResult() {}

  setUp(() {
    repository = InsightRepositoryMock();
    command = GetInsightsCommand(repository: repository);
    command.execute.results.addListener(onResult);

    insights = [
      InsightEntity(
        id: 'insight-1',
        group: 'comparison',
        title: 'Mais valor registrado',
        type: 'registered_amount_increase',
        description: 'Você registrou 35% mais valor.',
        period: InsightPeriodEntity(
          to: DateTime(2026, 10, 8),
          from: DateTime(2026, 10, 1),
        ),
      ),
    ];
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a result or a repository query', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  test(
    'publishes the repository result without transforming insights',
    () async {
      final response = Right<ErrorsEntity, List<InsightEntity>>(insights);
      when(() => repository.get()).thenAnswer((_) async => response);

      final data = await command.execute.runAsync((year: null, month: null));

      expect(data, same(insights));
      expect(command.execute.value, same(insights));
      expect(command.execute.results.value.data, same(insights));
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('publishes an empty list as a successful result', () async {
    when(() => repository.get()).thenAnswer((_) async => const Right([]));

    final data = await command.execute.runAsync((year: null, month: null));

    expect(data, isEmpty);
    expect(command.execute.value, isEmpty);
    expect(command.execute.results.value.hasError, isFalse);
  });

  test(
    'delegates reference months and preserves multi-month and null periods',
    () async {
      final multiMonth = InsightEntity(
        id: 'streak',
        group: 'comparison',
        type: 'category_lead_streak',
        title: 'Liderança recorrente',
        description: 'Moradia liderou por três meses.',
        period: InsightPeriodEntity(
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 9, 30),
        ),
      );
      const onboarding = InsightEntity(
        period: null,
        id: 'onboarding',
        group: 'onboarding',
        type: 'insufficient_history',
        title: 'Continue registrando',
        description: 'Cada registro traz contexto.',
      );
      final response = Right<ErrorsEntity, List<InsightEntity>>([
        multiMonth,
        onboarding,
      ]);
      when(() => repository.get(year: 2026, month: 9))
          .thenAnswer((_) async => response);

      final data = await command.execute.runAsync((year: 2026, month: 9));

      expect(data?.last.period, isNull);
      expect(data, same(response.right));
      expect(data, [multiMonth, onboarding]);
      expect(data?.first.period!.from, DateTime(2026, 7, 1));
      verify(() => repository.get(year: 2026, month: 9)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('preserves incomplete monthly filter errors without defaults', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          status: '422',
          title: 'Mês obrigatório',
          pointer: '/filter/month',
          parameter: 'filter[month]',
        ),
      ],
    );
    when(() => repository.get(year: 2026))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync((year: 2026, month: null)),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );

    final failure =
        command.execute.results.value.error as CommandFailureException;

    expect(failure.errors.errors.single.pointer, '/filter/month');
    expect(failure.errors.errors.single.parameter, 'filter[month]');
    verify(() => repository.get(year: 2026, month: null)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('publishes repository failures as typed errors', () async {
    final response = Left<ErrorsEntity, List<InsightEntity>>(
      ErrorsEntity.unknown(),
    );
    when(() => repository.get()).thenAnswer((_) async => response);

    await expectLater(
      command.execute.runAsync((year: null, month: null)),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(response.left),
        ),
      ),
    );

    expect(command.execute.results.value.hasError, isTrue);
    expect(command.execute.value, isNull);
    expect(
      command.execute.errors.value?.error,
      same(command.execute.results.value.error),
    );
  });

  test('allows another query after a failed load', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.get()).thenAnswer((_) async => Left(errors));
    await expectLater(
      command.execute.runAsync((year: null, month: null)),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );
    when(() => repository.get()).thenAnswer((_) async => Right(insights));

    final data = await command.execute.runAsync((year: null, month: null));

    expect(data, same(insights));
    expect(command.execute.value, same(insights));
    verify(() => repository.get()).called(2);
  });

  test(
    'replaces the previous result instead of accumulating insights',
    () async {
      when(() => repository.get()).thenAnswer((_) async => Right(insights));
      await command.execute.runAsync((year: null, month: null));
      when(() => repository.get()).thenAnswer((_) async => const Right([]));

      await command.execute.runAsync((year: null, month: null));

      expect(command.execute.value, isEmpty);
      verify(() => repository.get()).called(2);
    },
  );

  test('keeps loading and prevents duplicate queries while pending', () async {
    final pending = Completer<GetRepositoryType>();
    final started = Completer<void>();
    when(() => repository.get()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final data = command.execute.runAsync((year: null, month: null));
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run((year: null, month: null));
    verify(() => repository.get()).called(1);
    pending.complete(Right(insights));

    expect(await data, same(insights));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('keeps results isolated between command instances', () async {
    final otherCommand = GetInsightsCommand(repository: repository);
    when(() => repository.get()).thenAnswer((_) async => Right(insights));
    try {
      await command.execute.runAsync((year: null, month: null));

      expect(otherCommand.execute.value, isNull);
      expect(command.execute.value, same(insights));
      expect(otherCommand.execute.isRunning.value, isFalse);
    } finally {
      otherCommand.dispose();
    }
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.get()).thenAnswer((_) async => throw failure);
    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(
        command.execute.runAsync((year: null, month: null)),
        throwsA(same(failure)),
      );

      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });

  test('disposes execution and loading observables', () async {
    final disposable = GetInsightsCommand(repository: repository);
    disposable.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    void listener() {}
    expect(
      () => disposable.execute.addListener(listener),
      throwsAssertionError,
    );
    expect(
      () => disposable.execute.isRunning.addListener(listener),
      throwsAssertionError,
    );
    verifyZeroInteractions(repository);
  });

  test('does not publish insights after disposal during a query', () async {
    final started = Completer<void>();
    final pending = Completer<GetRepositoryType>();
    final disposable = GetInsightsCommand(repository: repository);
    when(() => repository.get()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final execution = disposable.execute.runAsync((year: null, month: null));
    await started.future;
    disposable.dispose();
    pending.complete(Right(insights));

    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.value, isNull);
    expect(disposable.execute.results.value.data, isNull);
    verify(() => repository.get()).called(1);
  });

  test(
    'preserves an empty failure after success without publishing old insights',
    () async {
      when(() => repository.get()).thenAnswer((_) async => Right(insights));
      await command.execute.runAsync((year: null, month: null));
      const errors = ErrorsEntity(errors: []);
      when(() => repository.get()).thenAnswer((_) async => const Left(errors));

      await expectLater(
        command.execute.runAsync((year: null, month: null)),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );

      expect(command.execute.value, same(insights));
      expect(command.execute.results.value.data, isNull);
      expect(command.execute.results.value.hasError, isTrue);
      expect(
        command.execute.errors.value?.error,
        same(command.execute.results.value.error),
      );
    },
  );
}
