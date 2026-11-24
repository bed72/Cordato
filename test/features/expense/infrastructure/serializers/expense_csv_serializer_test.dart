import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/value_objects/amount_value_object.dart';
import 'package:cordato/features/expense/infrastructure/serializers/expense_csv_serializer.dart';

void main() {
  const serializer = ExpenseCsvSerializer();

  ExpenseEntity expense({String description = 'Café', int cents = 123456}) =>
      ExpenseEntity(
        id: 42,
        description: description,
        occurredOn: DateTime.utc(2026, 11, 8, 23),
        cents: AmountValueObject.create(cents: cents),
        category: .food,
      );

  test('uses BOM, Portuguese headers, civil dates and Brazilian cents', () {
    final bytes = serializer.encode(expenses: [expense()]);

    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    expect(
      utf8.decode(bytes.sublist(3)),
      'Identificador;Data;Descrição;Categoria;Valor\r\n'
      '42;08/11/2026;Café;food;1234,56\r\n',
    );
  });

  for (final amount in [
    (cents: 1, text: '0,01'),
    (cents: 100, text: '1,00'),
    (cents: 9007199254740993, text: '90071992547409,93'),
  ]) {
    test('formats ${amount.cents} without double conversion', () {
      final bytes = serializer.encode(expenses: [expense(cents: amount.cents)]);

      expect(utf8.decode(bytes), contains(';${amount.text}\r\n'));
    });
  }

  test('round trips accents, quotes, delimiters and embedded newlines', () {
    const description = 'Café; "pão"\r\nsegunda linha';
    final bytes = serializer.encode(
      expenses: [expense(description: description)],
    );
    final rows = Csv(
      fieldDelimiter: ';',
      lineDelimiter: '\r\n',
    ).decode(utf8.decode(bytes.sublist(3)));

    expect(rows, hasLength(2));
    expect(rows[1], hasLength(5));
    expect(rows[1][2], description);
  });

  for (final description in [
    '=SUM(A1:A2)',
    '+1',
    '-1',
    '@formula',
    '  =formula',
    '\u0000+formula',
    '\tplain',
    '\rplain',
    '\nplain',
  ]) {
    test('neutralizes formula input ${jsonEncode(description)}', () {
      final entry = expense(description: description);
      final bytes = serializer.encode(expenses: [entry]);
      final rows = Csv(
        fieldDelimiter: ';',
        lineDelimiter: '\r\n',
      ).decode(utf8.decode(bytes.sublist(3)));

      expect(rows[1][2], "'$description");
      expect(entry.description, description);
    });
  }

  test('keeps empty and ordinary descriptions unchanged', () {
    final bytes = serializer.encode(
      expenses: [
        expense(description: ''),
        expense(description: 'Café + pão'),
      ],
    );

    expect(utf8.decode(bytes), contains(';;food;'));
    expect(utf8.decode(bytes), contains(';Café + pão;'));
  });
}
