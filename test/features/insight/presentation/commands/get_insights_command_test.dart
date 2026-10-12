import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';

import '../../../../support/insight/mocks/insight_repository_mock.dart';

void main() {
  late GetInsightsCommand command;
  late List<InsightEntity> insights;
  late InsightRepositoryMock repository;

  setUp(() {
    repository = InsightRepositoryMock();
    command = GetInsightsCommand(repository: repository);
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

  tearDown(() => command.dispose());

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

      final result = await command.execute.runAsync((year: null, month: null));

      expect(result, same(response));
      expect(command.execute.value, same(response));
      expect(command.execute.value?.right, same(insights));
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('publishes an empty list as a successful result', () async {
    when(() => repository.get()).thenAnswer((_) async => const Right([]));

    final result = await command.execute.runAsync((year: null, month: null));

    expect(result?.isRight, isTrue);
    expect(command.execute.value?.right, isEmpty);
  });

  test(
    'delegates reference months and preserves multi-month and null periods',
    () async {
      final multiMonth = InsightEntity(
        id: 'streak',
        title: 'Liderança recorrente',
        type: 'category_lead_streak',
        group: 'comparison',
        description: 'Moradia liderou por três meses.',
        period: InsightPeriodEntity(
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 9, 30),
        ),
      );
      const onboarding = InsightEntity(
        id: 'onboarding',
        title: 'Continue registrando',
        type: 'insufficient_history',
        group: 'onboarding',
        description: 'Cada registro traz contexto.',
        period: null,
      );
      final response = Right<ErrorsEntity, List<InsightEntity>>([
        multiMonth,
        onboarding,
      ]);
      when(() => repository.get(year: 2026, month: 9))
          .thenAnswer((_) async => response);

      final result = await command.execute.runAsync((year: 2026, month: 9));

      expect(result, same(response));
      expect(result?.right, [multiMonth, onboarding]);
      expect(result?.right.first.period!.from, DateTime(2026, 7, 1));
      expect(result?.right.last.period, isNull);
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
          parameter: 'filter[month]',
          pointer: '/filter/month',
        ),
      ],
    );
    when(() => repository.get(year: 2026))
        .thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync((year: 2026, month: null));

    expect(result?.left, same(errors));
    expect(result?.left.errors.single.parameter, 'filter[month]');
    expect(result?.left.errors.single.pointer, '/filter/month');
    verify(() => repository.get(year: 2026, month: null)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('preserves repository failures as results', () async {
    final response = Left<ErrorsEntity, List<InsightEntity>>(
      ErrorsEntity.unknown(),
    );
    when(() => repository.get()).thenAnswer((_) async => response);

    final result = await command.execute.runAsync((year: null, month: null));

    expect(result, same(response));
    expect(command.execute.value, same(response));
  });

  test('allows another query after a failed load', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.get()).thenAnswer((_) async => Left(errors));
    expect(
      (await command.execute.runAsync((year: null, month: null)))?.left,
      same(errors),
    );
    when(() => repository.get()).thenAnswer((_) async => Right(insights));

    final result = await command.execute.runAsync((year: null, month: null));

    expect(result?.right, same(insights));
    expect(command.execute.value?.right, same(insights));
    verify(() => repository.get()).called(2);
  });

  test(
    'replaces the previous result instead of accumulating insights',
    () async {
      when(() => repository.get()).thenAnswer((_) async => Right(insights));
      await command.execute.runAsync((year: null, month: null));
      when(() => repository.get()).thenAnswer((_) async => const Right([]));

      await command.execute.runAsync((year: null, month: null));

      expect(command.execute.value?.right, isEmpty);
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

    final result = command.execute.runAsync((year: null, month: null));
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run((year: null, month: null));
    verify(() => repository.get()).called(1);
    pending.complete(Right(insights));

    expect((await result)?.right, same(insights));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('keeps results isolated between command instances', () async {
    final otherCommand = GetInsightsCommand(repository: repository);
    when(() => repository.get()).thenAnswer((_) async => Right(insights));
    try {
      await command.execute.runAsync((year: null, month: null));

      expect(command.execute.value?.right, same(insights));
      expect(otherCommand.execute.value, isNull);
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
}
