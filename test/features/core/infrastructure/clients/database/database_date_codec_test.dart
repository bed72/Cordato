import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_date_codec.dart';

void main() {
  group('Civil date encoding', () {
    for (final sample in [
      (date: DateTime(1, 1, 1), encoded: '0001-01-01'),
      (date: DateTime(99, 9, 8), encoded: '0099-09-08'),
      (date: DateTime(2024, 2, 29), encoded: '2024-02-29'),
      (date: DateTime(9999, 12, 31), encoded: '9999-12-31'),
      (
        date: DateTime(2026, 11, 23, 23, 59, 59, 999, 999),
        encoded: '2026-11-23',
      ),
      (date: DateTime.utc(2026, 11, 23, 0, 1), encoded: '2026-11-23'),
    ]) {
      test('encodes ${sample.date} using only its civil components', () {
        final encoded = encodeDatabaseDate(
          sample.date,
          parameter: 'occurredOn',
        );

        expect(encoded, sample.encoded);
      });
    }
  });

  group('Year validation', () {
    for (final year in [-1, 0, 10000]) {
      for (final parameter in ['occurredOn', 'startDate', 'endDate']) {
        test('rejects year $year and identifies $parameter', () {
          final date = DateTime.utc(year, 1, 1);

          expect(
            () => encodeDatabaseDate(date, parameter: parameter),
            throwsA(
              isA<ArgumentError>()
                  .having((error) => error.name, 'name', parameter)
                  .having((error) => error.invalidValue, 'invalidValue', date),
            ),
          );
        });
      }
    }
  });
}
