import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/session_command.dart';

class _RepositoryMock extends Mock implements IAuthenticationRepository {}

void main() {
  test('reflects session changes and stops observing when disposed', () async {
    final repository = _RepositoryMock();
    final changes = StreamController<bool>.broadcast();
    addTearDown(changes.close);
    when(repository.hasSession).thenAnswer((_) => changes.stream);

    final command = SessionCommand(repository: repository);
    var disposed = false;
    addTearDown(() {
      if (!disposed) command.dispose();
    });
    expect(command.execute.value, isNull);
    verify(repository.hasSession).called(1);
    expect(changes.hasListener, isTrue);

    changes.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.value, isTrue);

    changes.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(command.execute.value, isFalse);

    command.dispose();
    disposed = true;
    await Future<void>.delayed(Duration.zero);
    expect(changes.hasListener, isFalse);
  });
}
