import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/main.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';

import '../../../../support/core/mocks/crash_client_mock.dart';
import '../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late CrashClientMock client;
  late ExpenseRepositoryMock repository;
  late GetExpensesCommand command;
  late void Function(CommandError<dynamic>, StackTrace)? previousHandler;

  const input = (
    pageSize: 6,
    pageLink: null,
    from: null,
    to: null,
    category: null,
  );

  setUpAll(() => registerFallbackValue(StackTrace.empty));

  setUp(() {
    previousHandler = Command.globalExceptionHandler;
    client = CrashClientMock();
    repository = ExpenseRepositoryMock();
    configureCommandExceptionHandler(client);
    command = GetExpensesCommand(repository: repository);
    when(
      () => client.recordError(
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        fatal: any(named: 'fatal'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    command.dispose();
    Command.globalExceptionHandler = previousHandler;
  });

  test(
    'installs the fallback without changing native or Flutter error policies',
    () {
      final filter = Command.errorFilterDefault;
      final assertionsAlwaysThrow = Command.assertionsAlwaysThrow;
      final reportAllExceptions = Command.reportAllExceptions;
      final flutterHandler = FlutterError.onError;
      final platformHandler = PlatformDispatcher.instance.onError;

      configureCommandExceptionHandler(client);

      expect(Command.globalExceptionHandler, isNotNull);
      expect(Command.errorFilterDefault, same(filter));
      expect(filter, isA<GlobalIfNoLocalErrorFilter>());
      expect(Command.assertionsAlwaysThrow, assertionsAlwaysThrow);
      expect(Command.assertionsAlwaysThrow, isTrue);
      expect(Command.reportAllExceptions, reportAllExceptions);
      expect(Command.reportAllExceptions, isFalse);
      expect(FlutterError.onError, same(flutterHandler));
      expect(PlatformDispatcher.instance.onError, same(platformHandler));
      verifyZeroInteractions(client);
    },
  );

  test(
    'completes a typed failure without a local handler or crash report',
    () async {
      final errors = ErrorsEntity(errors: []);
      final failure = CommandFailureException(errors: errors);
      when(() => repository.get(pageSize: 6)).thenThrow(failure);

      await expectLater(
        command.execute.runAsync(input),
        throwsA(same(failure)),
      );

      final result = command.execute.results.value;
      expect(result.hasError, isTrue);
      expect(result.error, same(failure));
      expect(result.data, isNull);
      expect(result.paramData, input);
      expect(command.execute.errors.value?.error, same(failure));
      expect(command.execute.isRunning.value, isFalse);
      expect(failure.errors, same(errors));
      verifyZeroInteractions(client);
      verify(() => repository.get(pageSize: 6)).called(1);
    },
  );

  test(
    'reports an unexpected failure once with the stack supplied by CommandIt',
    () async {
      final failure = StateError('repository unavailable');
      when(() => repository.get(pageSize: 6)).thenThrow(failure);

      await expectLater(
        command.execute.runAsync(input),
        throwsA(same(failure)),
      );

      final result = command.execute.results.value;
      expect(result.error, same(failure));
      expect(result.hasError, isTrue);
      expect(command.execute.isRunning.value, isFalse);
      final reported = verify(
        () => client.recordError(
          error: failure,
          stackTrace: captureAny(named: 'stackTrace'),
          fatal: false,
        ),
      );
      reported.called(1);
      expect(reported.captured.single, same(result.stackTrace));
      verifyNoMoreInteractions(client);
    },
  );

  for (final channel in ['results', 'errors']) {
    for (final typed in [true, false]) {
      test(
        'handles ${typed ? 'typed' : 'unexpected'} failure once via $channel without global reporting',
        () async {
          final failure = typed
              ? CommandFailureException(errors: ErrorsEntity.unknown())
              : StateError('repository unavailable');
          final page = ExpensePageEntity(items: [], next: null, prev: null);
          when(() => repository.get(pageSize: 6))
              .thenAnswer((_) async => Right(page));
          await command.execute.runAsync(input);
          final previousValue = command.execute.value;
          int localFailures = 0;
          Object? localError;

          void onFailure() {
            if (channel == 'results') {
              final result = command.execute.results.value;
              if (result.isRunning || !result.hasError) return;
              localError = result.error;
            } else {
              final error = command.execute.errors.value;
              if (error == null) return;
              localError = error.error;
            }
            localFailures++;
          }

          final signal = channel == 'results'
              ? command.execute.results
              : command.execute.errors;
          signal.addListener(onFailure);
          addTearDown(() => signal.removeListener(onFailure));
          when(() => repository.get(pageSize: 6)).thenThrow(failure);

          await expectLater(
            command.execute.runAsync(input),
            throwsA(same(failure)),
          );

          expect(localFailures, 1);
          expect(localError, same(failure));
          expect(command.execute.results.value.hasError, isTrue);
          expect(command.execute.results.value.data, isNull);
          expect(command.execute.errors.value?.error, same(failure));
          expect(command.execute.value, same(previousValue));
          expect(command.execute.isRunning.value, isFalse);
          verifyZeroInteractions(client);
          verify(() => repository.get(pageSize: 6)).called(2);
        },
      );
    }
  }
}
