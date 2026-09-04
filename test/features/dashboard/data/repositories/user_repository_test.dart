import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/dashboard/data/repositories/user_repository.dart';
import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';
import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/dashboard/infrastructure/remoto/user_data_source.dart';

class _UserDataSourceMock extends Mock implements IUserDataSource {}

void main() {
  late IUserDataSource dataSource;
  late IUserRepository repository;

  setUp(() {
    dataSource = _UserDataSourceMock();
    repository = UserRepository(dataSource: dataSource);
  });

  test('returns the current user name from the data source', () async {
    const user = UserEntity(name: 'Gabriel', email: 'gabriel@example.com');
    when(() => dataSource.getUser()).thenAnswer((_) async => user);

    expect(await repository.getUserName(), 'Gabriel');
    verify(() => dataSource.getUser()).called(1);
  });
}
