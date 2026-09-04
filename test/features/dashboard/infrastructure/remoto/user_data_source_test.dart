import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';
import 'package:cordato/features/dashboard/infrastructure/clients/supabase_user_client.dart';
import 'package:cordato/features/dashboard/infrastructure/remoto/user_data_source.dart';

class _UserClientMock extends Mock implements IUserClient {}

void main() {
  late IUserClient client;
  late IUserDataSource dataSource;

  setUp(() {
    client = _UserClientMock();
    dataSource = UserDataSource(client: client);
  });

  test('delegates the current user lookup', () async {
    const user = UserEntity(name: 'Gabriel', email: 'gabriel@example.com');
    when(() => client.getUser()).thenAnswer((_) async => user);

    expect(await dataSource.getUser(), user);
    verify(() => client.getUser()).called(1);
  });
}
