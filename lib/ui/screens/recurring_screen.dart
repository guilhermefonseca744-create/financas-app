import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final items = provider.recurrings;

    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos recorrentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text('Automatize salário, aluguel, assinaturas...',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        'O lançamento é criado sozinho todo mês no dia escolhido.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final r in items)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (r.type == TxType.income
                                ? AppTheme.income
                                : AppTheme.expense)
                            .withValues(alpha: 0.18),
                        child: Icon(
                          r.type == TxType.income
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: r.type == TxType.income
                              ? AppTheme.income
                              : AppTheme.expense,
                        ),
                      ),
                      title: Text(
                        r.description.isNotEmpty
                            ? r.description
                            : provider.categoryById(r.categoryId)?.name ??
                                r.type.label,
                      ),
                      subtitle: Text(
                          'Todo dia ${r.dayOfMonth} • ${Fmt.money(r.amount)}'
                          '${r.active ? '' : ' • pausado'}'),
                      trailing: Switch(
                        value: r.active,
                        onChanged: (v) => provider.updateRecurring(
                          Recurring(
                            id: r.id,
                            type: r.type,
                            amount: r.amount,
                            description: r.description,
                            accountId: r.accountId,
                            categoryId: r.categoryId,
                            dayOfMonth: r.dayOfMonth,
                            active: v,
                            lastGenerated: r.lastGenerated,
                          ),
                        ),
                      ),
                      onTap: () => _edit(context, r),
                    ),
                  ),
              ],
            ),
    );
  }

  void _edit(BuildContext context, Recurring? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecurringEditor(existing: existing),
    );
  }
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({this.existing});
  final Recurring? existing;

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  TxType _type = TxType.expense;
  int _day = 5;
  int? _accountId;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _description = TextEditingController(text: e?.description ?? '');
    _type = e?.type ?? TxType.expense;
    _day = e?.dayOfMonth ?? 5;
    _accountId = e?.accountId;
    _categoryId = e?.categoryId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<FinanceProvider>();
    _accountId ??= p.accounts.isNotEmpty ? p.accounts.first.id : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  double _parse(String v) =>
      double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ??
      double.tryParse(v) ??
      0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final r = Recurring(
      id: widget.existing?.id,
      type: _type,
      amount: _parse(_amount.text),
      description: _description.text.trim(),
      accountId: _accountId!,
      categoryId: _categoryId,
      dayOfMonth: _day,
      active: widget.existing?.active ?? true,
      lastGenerated: widget.existing?.lastGenerated,
    );
    if (widget.existing == null) {
      provider.addRecurring(r);
    } else {
      provider.updateRecurring(r);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cats = _type == TxType.income
        ? provider.incomeCategories
        : provider.expenseCategories;
    if (_categoryId != null && !cats.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  widget.existing == null
                      ? 'Novo recorrente'
                      : 'Editar recorrente',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Despesa')),
                  ButtonSegment(value: TxType.income, label: Text('Receita')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Valor', prefixText: 'R\$ '),
                validator: (v) =>
                    _parse(v ?? '') <= 0 ? 'Informe um valor' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Descrição', hintText: 'Ex: Salário, Netflix'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _accountId,
                decoration: const InputDecoration(labelText: 'Conta'),
                items: [
                  for (final a in provider.accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Selecione uma conta' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _day,
                decoration: const InputDecoration(labelText: 'Dia do mês'),
                items: [
                  for (int d = 1; d <= 28; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: (v) => setState(() => _day = v ?? 5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (widget.existing != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context
                              .read<FinanceProvider>()
                              .deleteRecurring(widget.existing!.id!);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                  if (widget.existing != null) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      style:
                          FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
