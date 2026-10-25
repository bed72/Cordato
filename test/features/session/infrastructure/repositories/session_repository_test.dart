import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';

import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  late StorageClientMock storage;
  late SessionRepository repository;

  setUp(() {
    storage = StorageClientMock();
    repository = SessionRepository(storage: storage);
  });

  for (final scenario in [
    (token: null, present: false),
    (token: '', present: false),
    (token: 'opaque-token', present: true),
    (token: ' ', present: true),
  ]) {
    test(
      'reads only the token presence without normalizing: ${scenario.present}/${scenario.token?.length}',
      () async {
        when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
            .thenAnswer((_) async => scenario.token);
        expect(await repository.loadSession(), scenario.present);
        verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
            .called(1);
        verifyNoMoreInteractions(storage);
      },
    );
  }

  test('waits for the initial storage read', () async {
    final pending = Completer<String?>();
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) => pending.future);
    var finished = false;
    final result = repository.loadSession().then((value) {
      finished = true;
      return value;
    });
    expect(finished, isFalse);
    pending.complete('opaque-token');
    expect(await result, isTrue);
  });

  test(
    'maps token changes to booleans without exposing token values',
    () async {
      when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key)).thenAnswer(
        (_) => Stream.fromIterable(['token', null, '', ' ', 'new-token']),
      );
      await expectLater(
        repository.sessionChanges,
        emitsInOrder([true, false, false, true, true, emitsDone]),
      );
      verify(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .called(1);
      verifyNoMoreInteractions(storage);
    },
  );

  for (final synchronous in [false, true]) {
    test(
      'propagates ${synchronous ? 'synchronous' : 'asynchronous'} read failures without inventing absence',
      () async {
        final failure = StateError('storage unavailable');
        if (synchronous) {
          when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
              .thenThrow(failure);
        } else {
          when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
              .thenAnswer((_) async => throw failure);
        }
        await expectLater(repository.loadSession(), throwsA(same(failure)));
        verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
            .called(1);
        verifyNoMoreInteractions(storage);
      },
    );
  }

  test(
    'propagates stream errors and continues forwarding later token changes',
    () async {
      final changes = StreamController<String?>();
      addTearDown(changes.close);
      when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) => changes.stream);
      final failure = StateError('watch unavailable');
      final result = expectLater(
        repository.sessionChanges,
        emitsInOrder([emitsError(same(failure)), true, emitsDone]),
      );
      changes.addError(failure);
      changes.add('token');
      await changes.close();
      await result;
    },
  );

  test('cancelling observation releases the storage listener', () async {
    final changes = StreamController<String?>.broadcast();
    addTearDown(changes.close);
    when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) => changes.stream);
    final subscription = repository.sessionChanges.listen((_) {});
    expect(changes.hasListener, isTrue);
    await subscription.cancel();
    expect(changes.hasListener, isFalse);
  });

  test('propagates a synchronous watch failure', () {
    final failure = StateError('watch unavailable');
    when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
        .thenThrow(failure);
    expect(() => repository.sessionChanges, throwsA(same(failure)));
  });
}
