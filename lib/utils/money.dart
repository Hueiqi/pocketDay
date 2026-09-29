import 'package:intl/intl.dart';

String symbol(String currency) => currency == 'MYR' ? 'RM' : 'S\$';
int? parseBalanceCents(String input) {
  final value = input.trim();
  if (!RegExp(r'^-?\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
  final negative = value.startsWith('-');
  final unsigned = negative ? value.substring(1) : value;
  final parts = unsigned.split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return negative ? -cents : cents;
}

int? parseCents(String input) {
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(input.trim())) return null;
  final parts = input.trim().split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return cents > 0 ? cents : null;
}

String money(int cents, String currency) =>
    '${symbol(currency)} ${NumberFormat('#,##0.00').format(cents / 100)}';
