import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../services/bank_import_service.dart';
import '../../state/finance_provider.dart';
import 'transaction_editor.dart';

class BankImportScreen extends StatefulWidget {
  const BankImportScreen({super.key});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  bool _granted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final granted = await BankImportService.isPermissionGranted();
    if (mounted) {
      setState(() {
        _granted = granted;
        _checking = false;
      });
    }
    if (granted) {
      // garante que a escuta está ativa
      await context.read<FinanceProvider>().startBankImport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final items = provider.pendingImports;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar do banco')),
      body: !BankImportService.isSupported
          ? const _DesktopNotice()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _PermissionCard(
                  granted: _granted,
                  checking: _checking,
                  onGrant: () async {
                    await BankImportService.requestPermission();
                    // volta das configs do Android
                    await _refreshPermission();
                  },
                  onRefresh: _refreshPermission,
                ),
                const SizedBox(height: 16),
                Text('Compras detectadas',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          _granted
                              ? 'Nada por aqui ainda. Quando o banco enviar uma notificação de compra, ela aparece aqui.'
                              : 'Ative o acesso às notificações para começar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                else
                  for (final pi in items)
                    _ImportTile(
                      provider: provider,
                      id: pi.id!,
                      amount: pi.amount,
                      merchant: pi.merchant,
                      rawText: pi.rawText,
                      createdAt: pi.createdAt,
                    ),
              ],
            ),
    );
  }
}

class _DesktopNotice extends StatelessWidget {
  const _DesktopNotice();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('Disponível apenas no Android',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  'A leitura de notificações do banco só funciona no aplicativo Android.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.granted,
    required this.checking,
    required this.onGrant,
    required this.onRefresh,
  });
  final bool granted;
  final bool checking;
  final VoidCallback onGrant;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: granted ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(granted ? Icons.check_circle : Icons.notifications_outlined,
                    color: granted ? Colors.green : scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    checking
                        ? 'Verificando permissão...'
                        : granted
                            ? 'Acesso a notificações ativo'
                            : 'Acesso a notificações desativado',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'O app lê as notificações de compra do seu banco para sugerir lançamentos. '
              'Tudo é processado no aparelho — nada é enviado para a internet.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!granted)
              FilledButton.icon(
                onPressed: onGrant,
                icon: const Icon(Icons.settings),
                label: const Text('Ativar acesso a notificações'),
              )
            else
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportTile extends StatelessWidget {
  const _ImportTile({
    required this.provider,
    required this.id,
    required this.amount,
    required this.merchant,
    required this.rawText,
    required this.createdAt,
  });
  final FinanceProvider provider;
  final int id;
  final double? amount;
  final String? merchant;
  final String rawText;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.notifications_active_outlined),
        ),
        title: Text(
          amount != null ? Fmt.money(amount!) : 'Valor não identificado',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${merchant ?? rawText}\n${Fmt.date(createdAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Descartar',
          onPressed: () => provider.deletePendingImport(id),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionEditor(
              initialAmount: amount,
              initialDescription: merchant ?? '',
              onSaved: () => provider.deletePendingImport(id),
            ),
          ),
        ),
      ),
    );
  }
}
