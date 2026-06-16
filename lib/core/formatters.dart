import 'package:intl/intl.dart';

/// Formatadores centralizados para moeda e datas (pt-BR).
class Fmt {
  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static final NumberFormat _compact =
      NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');

  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dateLong = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');
  static final DateFormat _month = DateFormat("MMMM 'de' y", 'pt_BR');
  static final DateFormat _monthKey = DateFormat('yyyy-MM');

  static String money(num value) => _currency.format(value);
  static String moneyCompact(num value) => _compact.format(value);
  static String date(DateTime d) => _date.format(d);
  static String dateLong(DateTime d) => _dateLong.format(d);
  static String month(DateTime d) => _month.format(d);

  /// Chave de mês no formato AAAA-MM (usada para orçamentos e filtros).
  static String monthKey(DateTime d) => _monthKey.format(d);
}
