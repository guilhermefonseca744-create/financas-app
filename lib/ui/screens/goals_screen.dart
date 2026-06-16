import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/finance_provider.dart';
import '../widgets/pickers.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final goals = provider.goals;

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      ),
      body: goals.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final g in goals) _GoalCard(goal: g),
              ],
            ),
    );
  }

  void _edit(BuildContext context, Goal? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditor(existing: existing),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_outlined,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('Crie uma meta de economia',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Ex: viagem, reserva de emergência, presente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    final done = goal.savedAmount >= goal.targetAmount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: goal.color.withValues(alpha: 0.18),
                  child: Icon(goal.icon, color: goal.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(goal.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                IconButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _GoalEditor(existing: goal),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 12,
                color: goal.color,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${Fmt.money(goal.savedAmount)} de ${Fmt.money(goal.targetAmount)}'),
                Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: goal.color)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _contribute(context, provider, -1),
                    icon: const Icon(Icons.remove),
                    label: const Text('Retirar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: done
                        ? null
                        : () => _contribute(context, provider, 1),
                    icon: const Icon(Icons.add),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
            if (done)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: goal.color, size: 18),
                    const SizedBox(width: 6),
                    const Text('Meta atingida! 🎉'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _contribute(BuildContext context, FinanceProvider provider, int sign) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sign > 0 ? 'Guardar na meta' : 'Retirar da meta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                      controller.text.replaceAll('.', '').replaceAll(',', '.')) ??
                  double.tryParse(controller.text);
              if (v != null && v > 0) {
                provider.addToGoal(goal.id!, sign * v);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({this.existing});
  final Goal? existing;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _target;
  int _color = kColorPalette.first;
  int _icon = Icons.savings.codePoint;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(
        text: e != null ? e.targetAmount.toStringAsFixed(2) : '');
    _color = e?.colorValue ?? kColorPalette.first;
    _icon = e?.iconCode ?? Icons.savings.codePoint;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  double _parse(String v) =>
      double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ??
      double.tryParse(v) ??
      0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final goal = Goal(
      id: widget.existing?.id,
      name: _name.text.trim(),
      targetAmount: _parse(_target.text),
      savedAmount: widget.existing?.savedAmount ?? 0,
      colorValue: _color,
      iconCode: _icon,
    );
    if (widget.existing == null) {
      provider.addGoal(goal);
    } else {
      provider.updateGoal(goal);
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
              Text(widget.existing == null ? 'Nova meta' : 'Editar meta',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nome da meta', hintText: 'Ex: Viagem'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _target,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Valor alvo', prefixText: 'R\$ '),
                validator: (v) =>
                    _parse(v ?? '') <= 0 ? 'Informe um valor' : null,
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
                              .deleteGoal(widget.existing!.id!);
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
