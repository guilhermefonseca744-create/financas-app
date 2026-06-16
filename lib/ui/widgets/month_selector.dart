import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../state/finance_provider.dart';

/// Seletor de mês com botões de navegação acessíveis.
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final label = Fmt.month(provider.selectedMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => provider.changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
          iconSize: 28,
        ),
        Expanded(
          child: Semantics(
            label: 'Mês selecionado: $label',
            child: Text(
              label[0].toUpperCase() + label.substring(1),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => provider.changeMonth(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
          iconSize: 28,
        ),
      ],
    );
  }
}
