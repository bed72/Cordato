import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

void main() {
  test('maps the typed database record to a pure entity', () {
    const record = ProfilesTableData(
      id: 1,
      name: 'Gabriel',
      seed: 'chosen-seed',
    );

    final profile = UserResponse.fromRecord(record).toEntity();

    expect(profile.id, 1);
    expect(profile.name, 'Gabriel');
    expect(profile.seed, 'chosen-seed');
  });

  test('preserves empty values and whitespace without normalization', () {
    const record = ProfilesTableData(id: 1, name: '  Nome  ', seed: '');

    final profile = UserResponse.fromRecord(record).toEntity();

    expect(profile.id, 1);
    expect(profile.name, '  Nome  ');
    expect(profile.seed, isEmpty);
  });
}
