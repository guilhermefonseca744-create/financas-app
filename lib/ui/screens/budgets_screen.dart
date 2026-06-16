import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';
import '../widgets/month_selector.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final categories = provider.expenseCategories;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orçamento mensal',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const MonthSelector(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final cat in categories)
                  _BudgetTile(category: cat, provider: provider),
                const SizedBox(height: 8),
                Text(
                  'Defina um limite por categoria. A barra fica vermelha quando você ultrapassa o orçamento.',
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.category, required this.provider});
  final Category category;
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final budget = provider.budgetFor(category.id!);
    final spent = provider.spentInCategory(category.id!);
    final limit = budget?.amount ?? 0;
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final over = limit > 0 && spent > limit;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: category.color.withValues(alpha: 0.18),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(category.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => _editBudget(context),
                  child: Text(limit > 0 ? 'Editar' : 'Definir'),
                ),
              ],
            ),
            if (limit > 0) ...[
              const SizedBox(height: 8),
              Semantics(
                label:
                    'Gasto ${Fmt.money(spent)} de ${Fmt.money(limit)} em ${category.name}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: over ? scheme.error : category.color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${Fmt.money(spent)} de ${Fmt.money(limit)}'),
                  Text(
                    over
                        ? 'Ultrapassou ${Fmt.money(spent - limit)}'
                        : 'Resta ${Fmt.money(limit - spent)}',
                    style: TextStyle(
                      color: over ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Sem orçamento • gasto ${Fmt.money(spent)}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }

  void _editBudget(BuildContext context) {
    final budget = provider.budgetFor(category.id!);
    final controller = TextEditingController(
        text: budget != null ? budget.amount.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Orçamento • ${category.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Limite mensal',
            prefixText: 'R\$ ',
          ),
        ),
        actions: [
          if (budget != null)
            TextButton(
              onPressed: () {
                provider.removeBudget(category.id!);
                Navigator.pop(ctx);
              },
              child: const Text('Remover'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text
                      .replaceAll('.', '')
                      .replaceAll(',', '.')) ??
                  double.tryParse(controller.text);
              if (value != null && value > 0) {
                provider.setBudget(category.id!, value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
