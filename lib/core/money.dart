import 'package:intl/intl.dart';

/// Currencies the app offers. Amounts are always integer minor units (centavos,
/// cents) paired with a currency code — never doubles, never mixed currencies.
class Currency {
  const Currency(this.code, this.symbol, this.name);
  final String code;
  final String symbol;
  final String name;
}

const kCurrencies = <String, Currency>{
  'PHP': Currency('PHP', '₱', 'Philippine peso'),
  'USD': Currency('USD', r'$', 'US dollar'),
  'EUR': Currency('EUR', '€', 'Euro'),
  'JPY': Currency('JPY', '¥', 'Japanese yen'),
};

String currencySymbol(String code) => kCurrencies[code]?.symbol ?? code;

final _fmt = NumberFormat('#,##0.00', 'en_US');

/// ₱1,234.50
String formatMoney(int minor, String currency) =>
    '${currencySymbol(currency)}${_fmt.format(minor.abs() / 100)}';

/// "+ ₱1,234.50" / "− ₱1,234.50" (proper minus sign).
String formatSigned(int minor, String currency) =>
    '${minor >= 0 ? '+' : '−'} ${formatMoney(minor, currency)}';

/// Parses "1,234.5" → 123450. Returns null when the text isn't a number.
int? parseMinor(String text) {
  final v = double.tryParse(text.replaceAll(',', '').trim());
  if (v == null) return null;
  return (v * 100).round();
}

/// Converts a whole-unit literal (used by the mock seed) to minor units.
int minor(num units) => (units * 100).round();
