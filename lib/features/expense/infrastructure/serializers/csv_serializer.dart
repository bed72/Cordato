import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

final class CsvSerializer {
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  final Csv _csv = Csv(fieldDelimiter: ';', lineDelimiter: '\r\n');

  CsvSerializer() {
    _bytes.add([0xef, 0xbb, 0xbf]);
    _append(['Identificador', 'Data', 'Descrição', 'Categoria', 'Valor (BRL)']);
  }

  void add(ExpenseResponse expense) {
    final amount = expense.amount;
    final date = expense.occurredOn;
    if (amount < 0) {
      throw const FormatException('Invalid expense amount');
    }

    _append([
      _text(expense.id),
      '${_pad(date.day)}/${_pad(date.month)}/${date.year.toString().padLeft(4, '0')}',
      _text(expense.description),
      _text(expense.category.value),
      '${amount ~/ 100},${_pad(amount % 100)}',
    ]);
  }

  Uint8List takeBytes() => _bytes.takeBytes();

  void _append(List<String> cells) {
    _bytes.add(utf8.encode(_csv.encode([cells])));
    _bytes.add([13, 10]);
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _text(String value) {
    final dangerous = RegExp(r'^[\s\x00-\x1f\x7f]*[=+\-@]|^[\t\r\n]');
    return dangerous.hasMatch(value) ? "'$value" : value;
  }
}
