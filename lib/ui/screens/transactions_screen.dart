import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';
import '../../state/settings_controller.dart';
import '../widgets/month_selector.dart';
import 'transaction_editor.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final txs = provider.filteredTransactions;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Transações',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _openFilters(context, provider),
                      icon: Badge(
                        isLabelVisible: provider.hasActiveFilters,
                        child: const Icon(Icons.filter_list),
                      ),
                      tooltip: 'Filtrar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: provider.setTxQuery,
                  decoration: InputDecoration(
                    hintText: 'Buscar por descrição ou categoria',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: provider.txQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              provider.setTxQuery('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const MonthSelector(),
                if (provider.hasActiveFilters)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        provider.clearFilters();
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Limpar filtros'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: txs.isEmpty
                ? _empty(context, provider.hasActiveFilters)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _TxTile(tx: txs[i], provider: provider),
                  ),
          ),
        ],
      ),
    );
  }

  void _openFilters(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _FilterSheet(provider: provider),
    );
  }

  Widget _empty(BuildContext context, bool filtered) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filtered ? Icons.search_off : Icons.receipt_long,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                  filtered
                      ? 'Nenhuma transação encontrada'
                      : 'Nenhuma transação neste mês',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                filtered
                    ? 'Tente ajustar a busca ou os filtros.'
                    : 'Toque em "Adicionar" para registrar uma receita ou despesa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.provider});
  final FinanceProvider provider;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  TxType? _type;
  int? _category;
  int? _account;

  @override
  void initState() {
    super.initState();
    _type = widget.provider.txTypeFilter;
    _category = widget.provider.txCategoryFilter;
    _account = widget.provider.txAccountFilter;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filtrar transações',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Tipo'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final t in TxType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final c in provider.categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _account,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Conta'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final a in provider.accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _account = v),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    provider.clearFilters();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48)),
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    provider.setTxFilters(
                        category: _category, account: _account, type: _type);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, required this.provider});
  final Tx tx;
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final cat = provider.categoryById(tx.categoryId);
    final account = provider.accountById(tx.accountId);

    final (Color color, IconData icon, String sign) = switch (tx.type) {
      TxType.income => (AppTheme.income, cat?.icon ?? Icons.arrow_downward, '+'),
      TxType.expense => (AppTheme.expense, cat?.icon ?? Icons.arrow_upward, '-'),
      TxType.transfer => (
          Theme.of(context).colorScheme.primary,
          Icons.swap_horiz,
          ''
        ),
    };

    var title = tx.description.isNotEmpty
        ? tx.description
        : (tx.type == TxType.transfer
            ? 'Transferência'
            : cat?.name ?? 'Sem categoria');
    if (tx.installmentTotal != null && tx.installmentIndex != null) {
      title = '$title (${tx.installmentIndex}/${tx.installmentTotal})';
    }

    final subtitle = switch (tx.type) {
      TxType.transfer =>
        '${account?.name ?? '?'} → ${provider.accountById(tx.toAccountId)?.name ?? '?'}',
      _ => '${cat?.name ?? 'Sem categoria'} • ${account?.name ?? ''}',
    };

    return Semantics(
      button: true,
      label:
          '$title, ${tx.type.label} de ${settings.money(tx.amount)} em ${Fmt.date(tx.date)}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: CircleAvatar(
          backgroundColor: (cat?.color ?? color).withValues(alpha: 0.18),
          child: Icon(icon, color: cat?.color ?? color),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$subtitle\n${Fmt.date(tx.date)}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tx.receiptPath != null) ...[
              Icon(Icons.attach_file,
                  size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 4),
            ],
            Text(
              '$sign ${settings.money(tx.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionEditor(existing: tx),
          ),
        ),
      ),
    );
  }
}
