import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/extensions/date_time_extension.dart';

void main() {
  test('formats only the local calendar date as ISO 8601', () {
    final value = DateTime(2026, 9, 8, 23, 59, 59);

    expect(value.toIsoDateString(), '2026-09-08');
  });
}
