import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final bills = provider.bills;

    return Scaffold(
      appBar: AppBar(title: const Text('Contas a pagar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: bills.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text('Cadastre contas a pagar',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Você verá lembretes do que vence no mês na tela inicial.',
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
              children: [for (final b in bills) _BillTile(bill: b)],
            ),
    );
  }

  void _edit(BuildContext context, Bill? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BillEditor(existing: existing),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final paid = provider.billPaidThisMonth(bill.id!);
    final now = DateTime.now();
    final overdue = !paid && now.day > bill.dueDay;

    final (Color color, String status) = paid
        ? (Colors.green, 'Paga este mês')
        : overdue
            ? (scheme.error, 'Vencida (dia ${bill.dueDay})')
            : (scheme.primary, 'Vence dia ${bill.dueDay}');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(
            paid ? Icons.check : Icons.receipt_long,
            color: color,
          ),
        ),
        title: Text(bill.name),
        subtitle: Text('$status • ${Fmt.money(bill.amount)}'),
        trailing: paid
            ? const Icon(Icons.done_all, color: Colors.green)
            : FilledButton(
                onPressed: () => _pay(context, provider),
                child: const Text('Pagar'),
              ),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _BillEditor(existing: bill),
        ),
      ),
    );
  }

  void _pay(BuildContext context, FinanceProvider provider) {
    final accounts = provider.accounts;
    int accountId = bill.accountId ?? (accounts.isNotEmpty ? accounts.first.id! : 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pagar ${bill.name}?'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Será criada uma despesa de ${Fmt.money(bill.amount)}.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: accountId,
                decoration: const InputDecoration(labelText: 'Pagar com'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => accountId = v ?? accountId),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              provider.payBill(bill, accountId);
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _BillEditor extends StatefulWidget {
  const _BillEditor({this.existing});
  final Bill? existing;

  @override
  State<_BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends State<_BillEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  int _day = 10;
  int? _categoryId;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _day = e?.dueDay ?? 10;
    _categoryId = e?.categoryId;
    _accountId = e?.accountId;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double _parse(String v) =>
      double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ??
      double.tryParse(v) ??
      0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final bill = Bill(
      id: widget.existing?.id,
      name: _name.text.trim(),
      amount: _parse(_amount.text),
      dueDay: _day,
      categoryId: _categoryId,
      accountId: _accountId,
      active: widget.existing?.active ?? true,
    );
    if (widget.existing == null) {
      provider.addBill(bill);
    } else {
      provider.updateBill(bill);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (_categoryId != null &&
        !provider.expenseCategories.any((c) => c.id == _categoryId)) {
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
              Text(widget.existing == null ? 'Nova conta' : 'Editar conta',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nome', hintText: 'Ex: Luz, Internet'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
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
              DropdownButtonFormField<int>(
                value: _day,
                decoration: const InputDecoration(labelText: 'Vence no dia'),
                items: [
                  for (int d = 1; d <= 28; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: (v) => setState(() => _day = v ?? 10),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Categoria (opcional)'),
                items: [
                  for (final c in provider.expenseCategories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
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
                              .deleteBill(widget.existing!.id!);
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
