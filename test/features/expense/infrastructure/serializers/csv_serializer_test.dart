import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/infrastructure/serializers/csv_serializer.dart';

void main() {
  ExpenseResponse expense({
    String description = 'Ônibus',
    int cents = 123456,
  }) => ExpenseResponse(
    id: 'expense-id',
    amount: cents,
    description: description,
    occurredOn: DateTime.utc(2026, 11, 8),
    category: ExpenseCategoryEnum.food,
  );

  List<List<dynamic>> rows(CsvSerializer serializer) => Csv(
    fieldDelimiter: ';',
    autoDetect: false,
  ).decode(utf8.decode(serializer.takeBytes()));

  test(
    'writes exact BOM, header, CRLF, civil date, category and BRL cells',
    () {
      final serializer = CsvSerializer()..add(expense());

      final bytes = serializer.takeBytes();

      expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
      expect(
        utf8.decode(bytes),
        'Identificador;Data;Descrição;Categoria;Valor (BRL)\r\n'
        'expense-id;08/11/2026;Ônibus;food;1234,56\r\n',
      );
    },
  );

  group('Exact integer money', () {
    for (final money in {
      0: '0,00',
      1: '0,01',
      99: '0,99',
      100: '1,00',
      9007199254740991: '90071992547409,91',
    }.entries) {
      test('${money.key} cents becomes ${money.value}', () {
        final serializer = CsvSerializer()..add(expense(cents: money.key));
        expect(rows(serializer).last.last, money.value);
      });
    }

    test('negative data is not silently formatted as valid money', () {
      expect(
        () => CsvSerializer().add(expense(cents: -1)),
        throwsFormatException,
      );
    });
  });

  test(
    'preserves accents, quotes, separators and embedded newlines in one field',
    () {
      const description = 'Café; "pão"\r\nSegunda linha';
      final serializer = CsvSerializer()
        ..add(expense(description: description));
      final decoded = rows(serializer);
      expect(decoded, hasLength(2));
      expect(decoded.last[2], description);
    },
  );

  group('Spreadsheet formula protection', () {
    for (final description in [
      '=SUM(A1:A2)',
      '+1',
      '-1',
      '@cmd',
      '  =1',
      '\u0000+1',
      '\ttexto',
      '\rtexto',
      '\ntexto',
      '\u00a0@cmd',
    ]) {
      test('neutralizes ${jsonEncode(description)}', () {
        final source = expense(description: description);
        final serializer = CsvSerializer()..add(source);
        expect(rows(serializer).last[2], "'$description");
        expect(source.description, description);
      });
    }

    test(
      'does not change ordinary leading whitespace or punctuation inside text',
      () {
        const description = '  Café + pão';
        final serializer = CsvSerializer()
          ..add(expense(description: description));
        expect(rows(serializer).last[2], description);
      },
    );
  });
}
