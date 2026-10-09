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
  late InsightRepositoryMock repository;
  late GetInsightsCommand command;
  late List<InsightEntity> insights;

  setUp(() {
    repository = InsightRepositoryMock();
    command = GetInsightsCommand(repository: repository);
    insights = [
      InsightEntity(
        id: 'insight-1',
        title: 'Mais valor registrado',
        type: 'registered_amount_increase',
        group: 'comparison',
        description: 'Você registrou 35% mais valor.',
        period: InsightPeriodEntity(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 8),
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

      final result = await command.execute.runAsync();

      expect(result, same(response));
      expect(command.execute.value, same(response));
      expect(command.execute.value?.right, same(insights));
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('publishes an empty list as a successful result', () async {
    when(() => repository.get()).thenAnswer((_) async => const Right([]));

    final result = await command.execute.runAsync();

    expect(result?.isRight, isTrue);
    expect(command.execute.value?.right, isEmpty);
  });

  test('preserves repository failures as results', () async {
    final response = Left<ErrorsEntity, List<InsightEntity>>(
      ErrorsEntity.unknown(),
    );
    when(() => repository.get()).thenAnswer((_) async => response);

    final result = await command.execute.runAsync();

    expect(result, same(response));
    expect(command.execute.value, same(response));
  });

  test('allows another query after a failed load', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.get()).thenAnswer((_) async => Left(errors));
    expect((await command.execute.runAsync())?.left, same(errors));
    when(() => repository.get()).thenAnswer((_) async => Right(insights));

    final result = await command.execute.runAsync();

    expect(result?.right, same(insights));
    expect(command.execute.value?.right, same(insights));
    verify(() => repository.get()).called(2);
  });

  test(
    'replaces the previous result instead of accumulating insights',
    () async {
      when(() => repository.get()).thenAnswer((_) async => Right(insights));
      await command.execute.runAsync();
      when(() => repository.get()).thenAnswer((_) async => const Right([]));

      await command.execute.runAsync();

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

    final result = command.execute.runAsync();
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run();
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
      await command.execute.runAsync();

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
      await expectLater(command.execute.runAsync(), throwsA(same(failure)));
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
