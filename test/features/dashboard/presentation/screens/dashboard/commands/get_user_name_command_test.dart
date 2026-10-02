import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_user_name_command.dart';

class _UserRepositoryMock extends Mock implements IUserRepository {}

void main() {
  late IUserRepository repository;
  late GetUserNameCommand command;

  setUp(() {
    repository = _UserRepositoryMock();
    command = GetUserNameCommand(repository: repository);
  });

  tearDown(() {
    command.dispose();
  });

  test('gets the user name through the repository', () async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');

    final result = await command.execute.runAsync();

    expect(result, 'Gabriel');
    verify(() => repository.getUserName()).called(1);
  });

  test('exposes repository failures as command errors', () async {
    final failure = StateError('could not get user name');
    when(() => repository.getUserName()).thenThrow(failure);

    void onResult() {}

    command.execute.results.addListener(onResult);
    await expectLater(command.execute.runAsync(), throwsA(same(failure)));
    command.execute.results.removeListener(onResult);
  });
}
