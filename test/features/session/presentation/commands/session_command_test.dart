import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/session/presentation/commands/session_command.dart';
import 'package:cordato/features/session/domain/repositories/interface_session_repository.dart';

class _RepositoryMock extends Mock implements ISessionRepository {}

void main() {
  late _RepositoryMock repository;
  late StreamController<bool> changes;
  late SessionCommand command;

  setUp(() {
    repository = _RepositoryMock();
    changes = StreamController<bool>.broadcast();
    when(() => repository.sessionChanges).thenAnswer((_) => changes.stream);
    command = SessionCommand(repository: repository);
  });

  tearDown(() async {
    command.dispose();
    await changes.close();
  });

  test('loads the stored session and tracks later changes', () async {
    when(repository.loadSession).thenAnswer((_) async => true);
    expect(command.execute.value, isNull);

    await command.loadSession();
    expect(command.execute.value, isTrue);
    changes.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.value, isFalse);
  });

  test(
    'does not replace a new session event with a stale initial read',
    () async {
      final pendingRead = Completer<bool>();
      when(repository.loadSession).thenAnswer((_) => pendingRead.future);

      final loading = command.loadSession();
      changes.add(true);
      await Future<void>.delayed(Duration.zero);
      pendingRead.complete(false);
      await loading;

      expect(command.execute.value, isTrue);
    },
  );

  test(
    'propagates read errors for the splash to navigate to welcome',
    () async {
      when(repository.loadSession)
          .thenAnswer((_) async => throw StateError('storage unavailable'));

      await expectLater(command.loadSession(), throwsA(isA<StateError>()));

      expect(command.execute.value, isNull);

      when(repository.loadSession).thenAnswer((_) async => false);
      await command.loadSession();
      expect(command.execute.value, isFalse);
    },
  );

  test('stops observing token changes when disposed', () async {
    expect(changes.hasListener, isTrue);
    command.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(changes.hasListener, isFalse);
    command = SessionCommand(repository: repository);
  });
}
