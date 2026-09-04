import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show GoTrueClient, SupabaseClient, User;

import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';
import 'package:cordato/features/dashboard/infrastructure/clients/supabase_user_client.dart';

class _GoTrueClientMock extends Mock implements GoTrueClient {}

class _SupabaseClientMock extends Mock implements SupabaseClient {}

class _UserMock extends Mock implements User {}

void main() {
  const email = 'person@example.com';

  late SupabaseClient supabaseClient;
  late GoTrueClient auth;
  late IUserClient client;

  setUp(() {
    supabaseClient = _SupabaseClientMock();
    auth = _GoTrueClientMock();
    client = SupabaseUserClient(client: supabaseClient);

    when(() => supabaseClient.auth).thenReturn(auth);
  });

  test('maps the authenticated Supabase user', () async {
    final user = _UserMock();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.userMetadata).thenReturn({'full_name': 'Gabriel Ramos'});
    when(() => user.email).thenReturn(email);

    final currentUser = await client.getUser();

    expect(currentUser, isA<UserEntity>());
    expect(currentUser?.name, 'Gabriel Ramos');
    expect(currentUser?.email, email);
  });

  test(
    'returns no user when there is no authenticated Supabase user',
    () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(await client.getUser(), isNull);
    },
  );
}
