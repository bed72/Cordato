import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late DateTime now;
  late DateFormatter formatter;

  setUp(() {
    now = DateTime(2026, 10, 7, 0, 1);
    formatter = DateFormatter(now: () => now);
  });

  group('DateFormatter', () {
    test('formats numeric dates with padded day and month', () {
      expect(formatter.formatShortDate(DateTime(2026, 1, 2)), '02/01/2026');
      expect(formatter.formatShortDate(DateTime(2024, 2, 29)), '29/02/2024');
    });

    test('preserves civil components of local and UTC dates', () {
      for (final date in [
        DateTime(2026, 10, 7, 23, 59),
        DateTime.utc(2026, 10, 7, 0, 1),
      ]) {
        expect(formatter.formatLongDate(date), '07 de Out');
        expect(formatter.relativeGroupHeader(date), 'Hoje');
        expect(formatter.formatShortDate(date), '07/10/2026');
      }
    });

    test('abbreviates months without a dot and includes other years', () {
      expect(formatter.formatLongDate(DateTime(2026, 1, 2)), '02 de Jan');
      expect(
        formatter.formatLongDate(DateTime(2025, 10, 7)),
        '07 de Out de 2025',
      );
      expect(
        formatter.formatLongDate(DateTime(2027, 10, 7)),
        '07 de Out de 2027',
      );
    });

    test('reads the current year on each call', () {
      final date = DateTime(2026, 12, 31);
      expect(formatter.formatLongDate(date), '31 de Dez');
      now = DateTime(2027, 1, 1);
      expect(formatter.formatLongDate(date), '31 de Dez de 2026');
    });

    test('formats full month names in Brazilian Portuguese', () {
      expect(formatter.formatMonth(DateTime(2026, 3)), 'Março');
      expect(formatter.formatMonth(DateTime(2026, 10)), 'Outubro');
    });

    test('collapses periods on the same civil day despite different times', () {
      final end = DateTime(2026, 10, 7, 23, 59);
      final start = DateTime.utc(2026, 10, 7, 0, 1);

      expect(formatter.formatPeriod(start, end), '07 de Out');
      expect(formatter.formatShortPeriod(start, end), '07/10/2026');
    });

    test('formats numeric periods with both complete dates', () {
      expect(
        formatter.formatShortPeriod(
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 2),
        ),
        '31/12/2025 até 02/01/2026',
      );
    });

    test('includes the year on each endpoint outside this year', () {
      expect(
        formatter.formatPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 7)),
        '01 de Out até 07 de Out',
      );
      expect(
        formatter.formatPeriod(DateTime(2024, 12, 31), DateTime(2025, 1, 2)),
        '31 de Dez de 2024 até 02 de Jan de 2025',
      );
      expect(
        formatter.formatPeriod(DateTime(2025, 12, 31), DateTime(2026, 1, 2)),
        '31 de Dez de 2025 até 02 de Jan',
      );
    });

    test('assigns each current-month date to its most specific period', () {
      expect(formatter.relativeGroupHeader(DateTime(2026, 10, 7, 23)), 'Hoje');
      expect(formatter.relativeGroupHeader(DateTime(2026, 10, 1)), 'Este mês');
      expect(
        formatter.relativeGroupHeader(DateTime(2026, 10, 6, 23, 59)),
        'Esta semana',
      );
      expect(
        formatter.relativeGroupHeader(DateTime(2026, 10, 5, 23, 59)),
        'Esta semana',
      );
      expect(
        formatter.relativeGroupHeader(DateTime(2026, 9, 30)),
        'Setembro de 2026',
      );
    });

    test('groups future and older dates by month and year', () {
      expect(
        formatter.relativeGroupHeader(DateTime(2026, 10, 8)),
        'Outubro de 2026',
      );
      expect(
        formatter.relativeGroupHeader(DateTime(2025, 10, 7)),
        'Outubro de 2025',
      );
    });

    test('starts the calendar week on Monday rather than seven days ago', () {
      now = DateTime(2026, 10, 12);
      expect(formatter.relativeGroupHeader(DateTime(2026, 10, 12)), 'Hoje');
      expect(formatter.relativeGroupHeader(DateTime(2026, 10, 11)), 'Este mês');

      now = DateTime(2026, 10, 18);
      expect(
        formatter.relativeGroupHeader(DateTime.utc(2026, 10, 12, 23, 59)),
        'Esta semana',
      );
      expect(formatter.relativeGroupHeader(DateTime(2026, 10, 11)), 'Este mês');
    });

    test('keeps the previous month monthly when a week crosses months', () {
      now = DateTime(2026, 10, 1);
      expect(formatter.relativeGroupHeader(DateTime(2026, 10, 1)), 'Hoje');
      expect(
        formatter.relativeGroupHeader(DateTime(2026, 9, 30)),
        'Setembro de 2026',
      );
    });

    test(
      'distinguishes the same month in different years at the year boundary',
      () {
        now = DateTime(2027, 1, 2);
        expect(
          formatter.relativeGroupHeader(DateTime(2027, 1, 1)),
          'Esta semana',
        );
        expect(
          formatter.relativeGroupHeader(DateTime(2026, 12, 31)),
          'Dezembro de 2026',
        );
        expect(
          formatter.relativeGroupHeader(DateTime(2026, 1, 2)),
          'Janeiro de 2026',
        );
      },
    );

    test('updates relative groups when the current civil date changes', () {
      final date = DateTime(2026, 10, 7);
      expect(formatter.relativeGroupHeader(date), 'Hoje');

      now = DateTime(2026, 10, 8);
      expect(formatter.relativeGroupHeader(date), 'Esta semana');

      now = DateTime(2026, 10, 12);
      expect(formatter.relativeGroupHeader(date), 'Este mês');

      now = DateTime(2026, 11, 1);
      expect(formatter.relativeGroupHeader(date), 'Outubro de 2026');
    });
  });
}
