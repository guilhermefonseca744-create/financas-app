// Teste placeholder. O app real precisa de inicialização assíncrona do banco
// (ver main.dart), então o smoke test padrão do Flutter foi substituído.
import 'package:flutter_test/flutter_test.dart';

import 'package:financas_app/core/formatters.dart';

void main() {
  test('Fmt.monthKey formata AAAA-MM', () {
    expect(Fmt.monthKey(DateTime(2026, 6, 15)), '2026-06');
  });
}
