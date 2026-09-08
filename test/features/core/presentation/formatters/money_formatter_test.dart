import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

void main() {
  final formatter = MoneyFormatter();

  group('MoneyFormatter', () {
    group('formatCents', () {
      test('formats zero, cents, whole values and grouped values as BRL', () {
        final cases = <int, String>{
          0: 'R\$ 0,00',
          1: 'R\$ 0,01',
          90: 'R\$ 0,90',
          100: 'R\$ 1,00',
          123456: 'R\$ 1.234,56',
          999999999: 'R\$ 9.999.999,99',
        };

        for (final entry in cases.entries) {
          expect(formatter.formatCents(entry.key), equals(entry.value));
        }
      });

      test('rejects negative cents', () {
        expect(() => formatter.formatCents(-1), throwsArgumentError);
      });
    });

    group('formatCentsWithoutSymbol', () {
      test('formats cents without the BRL symbol', () {
        expect(formatter.formatCentsWithoutSymbol(90), equals('0,90'));
        expect(formatter.formatCentsWithoutSymbol(123456), equals('1.234,56'));
      });
    });

    group('parseToCents', () {
      test('parses formatted and unformatted BRL values to cents', () {
        final cases = <String, int>{
          'R\$ 1.234,56': 123456,
          '  1.234,56  ': 123456,
          '90': 9000,
          '90,5': 9050,
          '0,01': 1,
          ',50': 50,
          '1,': 100,
        };

        for (final entry in cases.entries) {
          expect(formatter.parseToCents(entry.key), equals(entry.value));
        }
      });

      test('returns zero for empty, negative and malformed values', () {
        for (final value in [
          '',
          'R\$',
          '-1,00',
          '1.23',
          '1,234',
          '1,23,45',
          'valor',
        ]) {
          expect(formatter.parseToCents(value), equals(0));
        }
      });

      test('round trips valid cent values through BRL text', () {
        for (final cents in [0, 1, 90, 100, 123456, 999999999]) {
          expect(
            formatter.parseToCents(formatter.formatCents(cents)),
            equals(cents),
          );
        }
      });
    });
  });
}
