abstract interface class IMoneyFormatter {
  int parseToCents(String value);

  String formatCents(int cents);

  String formatCentsWithoutSymbol(int cents);
}
