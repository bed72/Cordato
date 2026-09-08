import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/enums/postgres_error_code_enum.dart';

void main() {
  test('exposes the PostgreSQL exclusion violation code', () {
    expect(PostgresErrorCodeEnum.exclusionViolation.value, '23P01');
  });
}
