import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';
import '../../state/settings_controller.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final accounts = provider.accounts;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Contas e cartões',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final a in accounts)
                  _AccountCard(account: a, provider: provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, {Account? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AccountEditorSheet(existing: existing),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.provider});
  final Account account;
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final balance = provider.balanceOf(account.id!);
    final isCard = account.type == AccountType.creditCard;

    final showInvoice =
        isCard && account.closingDay != null && account.dueDay != null;

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: account.color,
              child: Icon(account.type.icon, color: Colors.white),
            ),
            title: Text(account.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              isCard && account.creditLimit != null
                  ? '${account.type.label} • Limite ${Fmt.money(account.creditLimit!)}'
                  : account.type.label,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  settings.money(balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: balance < 0
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const Text('saldo', style: TextStyle(fontSize: 11)),
              ],
            ),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => AccountEditorSheet(existing: account),
            ),
          ),
          if (showInvoice)
            FutureBuilder<
                ({double amount, DateTime closeDate, DateTime dueDate})?>(
              future: provider.invoiceOf(account),
              builder: (context, snap) {
                if (!snap.hasData || snap.data == null) {
                  return const SizedBox.shrink();
                }
                final inv = snap.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fatura atual: ${settings.money(inv.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('vence ${Fmt.date(inv.dueDate)}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Formulário de criação/edição de conta.
class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key, this.existing});
  final Account? existing;

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _initial;
  late final TextEditingController _limit;
  AccountType _type = AccountType.cash;
  int _color = Colors.teal.value;
  int? _closingDay;
  int? _dueDay;

  static const _palette = [
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFF4E342E),
    Color(0xFF455A64),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _initial = TextEditingController(
        text: e != null ? e.initialBalance.toStringAsFixed(2) : '');
    _limit = TextEditingController(
        text: e?.creditLimit != null
            ? e!.creditLimit!.toStringAsFixed(2)
            : '');
    _type = e?.type ?? AccountType.cash;
    _color = e?.colorValue ?? _palette.first.value;
    _closingDay = e?.closingDay;
    _dueDay = e?.dueDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    _limit.dispose();
    super.dispose();
  }

  double _parse(String v) =>
      double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ??
      double.tryParse(v) ??
      0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final account = Account(
      id: widget.existing?.id,
      name: _name.text.trim(),
      type: _type,
      initialBalance: _parse(_initial.text),
      creditLimit: _type == AccountType.creditCard && _limit.text.isNotEmpty
          ? _parse(_limit.text)
          : null,
      closingDay: _type == AccountType.creditCard ? _closingDay : null,
      dueDay: _type == AccountType.creditCard ? _dueDay : null,
      colorValue: _color,
    );
    if (widget.existing == null) {
      provider.addAccount(account);
    } else {
      provider.updateAccount(account);
    }
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: Text(
            'A conta "${widget.existing!.name}" e suas transações serão removidas. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              context
                  .read<FinanceProvider>()
                  .deleteAccount(widget.existing!.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  labelText: 'Nome da conta',
                  hintText: 'Ex: Nubank, Carteira',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in AccountType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _initial,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial',
                  prefixText: 'R\$ ',
                ),
              ),
              if (_type == AccountType.creditCard) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limit,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Limite do cartão',
                    prefixText: 'R\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _closingDay,
                        decoration:
                            const InputDecoration(labelText: 'Fecha dia'),
                        items: [
                          for (int d = 1; d <= 28; d++)
                            DropdownMenuItem(value: d, child: Text('$d')),
                        ],
                        onChanged: (v) => setState(() => _closingDay = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _dueDay,
                        decoration:
                            const InputDecoration(labelText: 'Vence dia'),
                        items: [
                          for (int d = 1; d <= 28; d++)
                            DropdownMenuItem(value: d, child: Text('$d')),
                        ],
                        onChanged: (v) => setState(() => _dueDay = v),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('Cor'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in _palette)
                    Semantics(
                      label: 'Cor',
                      selected: _color == c.value,
                      button: true,
                      child: InkWell(
                        onTap: () => setState(() => _color = c.value),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c.value
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: _color == c.value
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (widget.existing != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                  if (widget.existing != null) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
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
