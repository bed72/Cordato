import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/session/application/repositories/session_repository.dart';

import '../../../../support/session/mocks/session_local_data_source_mock.dart';

void main() {
  test('delegates the initial session and subsequent changes', () async {
    final dataSource = SessionLocalDataSourceMock();
    final repository = SessionRepository(dataSource: dataSource);
    when(dataSource.loadSession).thenAnswer((_) async => false);
    when(() => dataSource.sessionChanges)
        .thenAnswer((_) => Stream<bool>.fromIterable([true, false]));

    expect(await repository.loadSession(), isFalse);
    await expectLater(repository.sessionChanges, emitsInOrder([true, false]));

    verify(dataSource.loadSession).called(1);
    verify(() => dataSource.sessionChanges).called(1);
  });
}
