import 'package:intl/intl.dart';

import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class MoneyFormatter implements IMoneyFormatter {
  static final _currencyPrefix = RegExp(r'^R\$\s*');
  static final _wholeNumber = RegExp(r'^(?:\d{1,3}(?:\.\d{3})*|\d+)$');
  static final _decimalNumber = RegExp(r'^\d{0,2}$');

  final NumberFormat _wholeNumberFormatter = NumberFormat.decimalPattern(
    'pt_BR',
  );

  @override
  String formatCents(int cents) => 'R\$ ${formatCentsWithoutSymbol(cents)}';

  @override
  String formatCentsWithoutSymbol(int cents) {
    if (cents < 0) throw ArgumentError.value(cents, 'cents');

    final whole = cents ~/ 100;
    final decimal = cents.remainder(100).toString().padLeft(2, '0');

    return '${_wholeNumberFormatter.format(whole)},$decimal';
  }

  @override
  int parseToCents(String value) {
    final normalized = value.trim().replaceFirst(_currencyPrefix, '');
    if (normalized.isEmpty) return 0;

    final parts = normalized.split(',');
    if (parts.length > 2 || normalized.startsWith('-')) return 0;

    final wholeText = parts.first;
    final decimalText = parts.length == 2 ? parts.last : '';
    if (wholeText.isNotEmpty && !_wholeNumber.hasMatch(wholeText)) return 0;
    if (!_decimalNumber.hasMatch(decimalText)) return 0;

    final whole = int.tryParse(wholeText.replaceAll('.', '')) ?? 0;
    final decimal = decimalText.padRight(2, '0');

    return (whole * 100) + (int.tryParse(decimal) ?? 0);
  }
}
