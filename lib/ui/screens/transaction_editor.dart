import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';

/// Formulário para criar/editar uma transação (receita, despesa ou transferência).
class TransactionEditor extends StatefulWidget {
  const TransactionEditor({super.key, this.existing});
  final Tx? existing;

  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;

  TxType _type = TxType.expense;
  DateTime _date = DateTime.now();
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  int _installments = 1;
  bool _makeRecurring = false;
  String? _receiptPath;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _description = TextEditingController(text: e?.description ?? '');
    if (e != null) {
      _type = e.type;
      _date = e.date;
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _receiptPath = e.receiptPath;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<FinanceProvider>();
    _accountId ??=
        provider.accounts.isNotEmpty ? provider.accounts.first.id : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  double _parseAmount(String v) {
    final cleaned = v.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? double.tryParse(v) ?? 0;
  }

  List<Category> _categoriesForType(FinanceProvider provider) =>
      _type == TxType.income
          ? provider.incomeCategories
          : provider.expenseCategories;

  bool _isSelectedCard(FinanceProvider provider) =>
      provider.accountById(_accountId)?.type == AccountType.creditCard;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: 'Selecione a data',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
      if (file == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final receipts = Directory(p.join(dir.path, 'receipts'));
      if (!receipts.existsSync()) receipts.createSync(recursive: true);
      final dest =
          p.join(receipts.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(file.path).copy(dest);
      setState(() => _receiptPath = dest);
    } catch (e) {
      _showError('Não foi possível anexar a imagem.');
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_type == TxType.transfer && _accountId == _toAccountId) {
      _showError('A conta de origem e destino devem ser diferentes.');
      return;
    }

    final provider = context.read<FinanceProvider>();
    final total = _parseAmount(_amount.text);
    final desc = _description.text.trim();

    // Edição: atualiza a transação existente.
    if (_isEditing) {
      provider.updateTransaction(widget.existing!.copyWith(
        type: _type,
        amount: total,
        description: desc,
        date: _date,
        accountId: _accountId,
        categoryId: _type == TxType.transfer ? null : _categoryId,
        toAccountId: _type == TxType.transfer ? _toAccountId : null,
        receiptPath: _receiptPath,
      ));
      Navigator.of(context).pop();
      return;
    }

    // Parcelamento no cartão (somente despesa em cartão e N > 1).
    final canInstall =
        _type == TxType.expense && _isSelectedCard(provider) && _installments > 1;

    if (canInstall) {
      final group = DateTime.now().microsecondsSinceEpoch.toString();
      final part = double.parse((total / _installments).toStringAsFixed(2));
      final txs = <Tx>[
        for (int i = 0; i < _installments; i++)
          Tx(
            type: TxType.expense,
            amount: part,
            description: desc,
            date: DateTime(_date.year, _date.month + i, _date.day),
            accountId: _accountId!,
            categoryId: _categoryId,
            toAccountId: null,
            installmentGroup: group,
            installmentIndex: i + 1,
            installmentTotal: _installments,
            receiptPath: i == 0 ? _receiptPath : null,
          ),
      ];
      provider.addTransactions(txs);
    } else {
      provider.addTransaction(Tx(
        type: _type,
        amount: total,
        description: desc,
        date: _date,
        accountId: _accountId!,
        categoryId: _type == TxType.transfer ? null : _categoryId,
        toAccountId: _type == TxType.transfer ? _toAccountId : null,
        receiptPath: _receiptPath,
      ));
    }

    // Tornar recorrente (não vale para transferências).
    if (_makeRecurring && _type != TxType.transfer) {
      provider.addRecurring(Recurring(
        type: _type,
        amount: total,
        description: desc,
        accountId: _accountId!,
        categoryId: _categoryId,
        dayOfMonth: _date.day.clamp(1, 28),
        active: true,
        lastGenerated: Fmt.monthKey(DateTime.now()),
      ));
    }

    Navigator.of(context).pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transação?'),
        content: const Text('Esta ação não pode ser desfeita.'),
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
                  .deleteTransaction(widget.existing!.id!);
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
    final provider = context.watch<FinanceProvider>();
    final categories = _categoriesForType(provider);
    final isCard = _isSelectedCard(provider);

    if (_type != TxType.transfer &&
        _categoryId != null &&
        !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar transação' : 'Nova transação'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir',
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(
                      value: TxType.expense,
                      label: Text('Despesa'),
                      icon: Icon(Icons.arrow_upward)),
                  ButtonSegment(
                      value: TxType.income,
                      label: Text('Receita'),
                      icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(
                      value: TxType.transfer,
                      label: Text('Transf.'),
                      icon: Icon(Icons.swap_horiz)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                  if (_type != TxType.expense) _installments = 1;
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amount,
                autofocus: !_isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                  prefixStyle: TextStyle(
                      fontSize: 24,
                      color: switch (_type) {
                        TxType.income => AppTheme.income,
                        TxType.expense => AppTheme.expense,
                        TxType.transfer =>
                          Theme.of(context).colorScheme.primary,
                      }),
                ),
                validator: (v) {
                  if (_parseAmount(v ?? '') <= 0) {
                    return 'Informe um valor maior que zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _accountId,
                decoration: InputDecoration(
                  labelText:
                      _type == TxType.transfer ? 'Conta de origem' : 'Conta',
                  prefixIcon:
                      const Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  for (final a in provider.accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Selecione uma conta' : null,
              ),
              if (_type == TxType.transfer) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _toAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Conta de destino',
                    prefixIcon: Icon(Icons.south_east),
                  ),
                  items: [
                    for (final a in provider.accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _toAccountId = v),
                  validator: (v) =>
                      v == null ? 'Selecione a conta de destino' : null,
                ),
              ],
              if (_type != TxType.transfer) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(c.icon, color: c.color, size: 20),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) =>
                      v == null ? 'Selecione uma categoria' : null,
                ),
              ],
              // Parcelamento (somente despesa em cartão e nova transação)
              if (!_isEditing && _type == TxType.expense && isCard) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _installments,
                  decoration: const InputDecoration(
                    labelText: 'Parcelas',
                    prefixIcon: Icon(Icons.view_week_outlined),
                  ),
                  items: [
                    for (int n = 1; n <= 24; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text(n == 1 ? 'À vista' : '$n x'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _installments = v ?? 1),
                ),
                if (_installments > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      '${_installments}x de ${Fmt.money(_parseAmount(_amount.text) / _installments)}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(Fmt.dateLong(_date)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  prefixIcon: Icon(Icons.notes),
                  hintText: 'Ex: Almoço, Conta de luz',
                ),
              ),
              const SizedBox(height: 16),
              // Recibo
              _ReceiptField(
                path: _receiptPath,
                onPick: _pickReceipt,
                onRemove: () => setState(() => _receiptPath = null),
              ),
              // Tornar recorrente (somente nova, não transferência)
              if (!_isEditing && _type != TxType.transfer) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _makeRecurring,
                  onChanged: (v) => setState(() => _makeRecurring = v),
                  title: const Text('Repetir todo mês'),
                  subtitle: const Text('Cria um lançamento recorrente.'),
                  secondary: const Icon(Icons.repeat),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Salvar'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptField extends StatelessWidget {
  const _ReceiptField({
    required this.path,
    required this.onPick,
    required this.onRemove,
  });
  final String? path;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Anexar recibo'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path!),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Recibo anexado')),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close),
          tooltip: 'Remover recibo',
        ),
      ],
    );
  }
}
