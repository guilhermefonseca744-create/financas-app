import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/finance_provider.dart';
import '../widgets/pickers.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _group(context, 'Despesas', provider.expenseCategories),
          const SizedBox(height: 16),
          _group(context, 'Receitas', provider.incomeCategories),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Category> cats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final c in cats)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c.color.withValues(alpha: 0.18),
                    child: Icon(c.icon, color: c.color),
                  ),
                  title: Text(c.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(context, c),
                ),
              if (cats.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma categoria.'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _edit(BuildContext context, Category? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryEditor(existing: existing),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.existing});
  final Category? existing;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  TxType _type = TxType.expense;
  int _color = kColorPalette.first;
  int _icon = kIconChoices.first.codePoint;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _type = e?.type ?? TxType.expense;
    _color = e?.colorValue ?? kColorPalette.first;
    _icon = e?.iconCode ?? kIconChoices.first.codePoint;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final cat = Category(
      id: widget.existing?.id,
      name: _name.text.trim(),
      type: _type,
      iconCode: _icon,
      colorValue: _color,
    );
    if (widget.existing == null) {
      provider.addCategory(cat);
    } else {
      provider.updateCategory(cat);
    }
    Navigator.pop(context);
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
              Text(
                  widget.existing == null
                      ? 'Nova categoria'
                      : 'Editar categoria',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Despesa')),
                  ButtonSegment(value: TxType.income, label: Text('Receita')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              const Text('Cor'),
              const SizedBox(height: 8),
              ColorPickerWrap(
                  selected: _color, onSelect: (c) => setState(() => _color = c)),
              const SizedBox(height: 16),
              const Text('Ícone'),
              const SizedBox(height: 8),
              IconPickerWrap(
                selectedCode: _icon,
                color: Color(_color),
                onSelect: (i) => setState(() => _icon = i),
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
                              .deleteCategory(widget.existing!.id!);
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
