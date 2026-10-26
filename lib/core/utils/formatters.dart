import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(
  locale: 'ru_RU',
  symbol: '',
  decimalDigits: 2,
);

String formatMoney(num value) => _moneyFormat.format(value).trim();
