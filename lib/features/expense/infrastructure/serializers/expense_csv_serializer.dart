import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

final class const ExpenseCsvSerializer() {
  Uint8List encode({required Iterable<ExpenseEntity> expenses}) {
    final rows = <List<String>>[
      ['Identificador', 'Data', 'Descrição', 'Categoria', 'Valor'],
      for (final expense in expenses)
        [
          expense.id.toString(),
          '${_pad(expense.occurredOn.day)}/${_pad(expense.occurredOn.month)}/${expense.occurredOn.year.toString().padLeft(4, '0')}',
          _text(expense.description),
          _text(expense.category.value),
          '${expense.cents.cents ~/ 100},${_pad(expense.cents.cents % 100)}',
        ],
    ];
    final csv = Csv(fieldDelimiter: ';', lineDelimiter: '\r\n');
    return .fromList([
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode('${csv.encode(rows)}\r\n'),
    ]);
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _text(String value) {
    final dangerous = RegExp(r'^[\s\x00-\x1f\x7f]*[=+\-@]|^[\t\r\n]');
    return dangerous.hasMatch(value) ? "'$value" : value;
  }
}
