import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/update_service.dart';
import '../../state/finance_provider.dart';
import '../../state/settings_controller.dart';
import '../update_flow.dart';
import 'bills_screen.dart';
import 'categories_screen.dart';
import 'goals_screen.dart';
import 'lock_screen.dart';
import 'recurring_screen.dart';
import 'reports_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Configurações',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ---------- Aparência ----------
          _SectionCard(
            title: 'Aparência',
            icon: Icons.palette_outlined,
            children: [
              const _Label('Tema'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistema'),
                      icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Claro'),
                      icon: Icon(Icons.light_mode)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Escuro'),
                      icon: Icon(Icons.dark_mode)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
              const SizedBox(height: 20),
              const _Label('Cor de destaque'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in SettingsController.accentPalette)
                    _ColorDot(
                      color: Color(c),
                      selected: settings.seedValue == c,
                      onTap: () => settings.setSeed(c),
                    ),
                ],
              ),
            ],
          ),

          // ---------- Ferramentas ----------
          _SectionCard(
            title: 'Ferramentas',
            icon: Icons.widgets_outlined,
            children: [
              _NavTile(
                icon: Icons.repeat,
                title: 'Lançamentos recorrentes',
                subtitle: 'Salário, assinaturas e contas fixas automáticas',
                page: const RecurringScreen(),
              ),
              _NavTile(
                icon: Icons.notifications_outlined,
                title: 'Contas a pagar',
                subtitle: 'Lembretes do que vence no mês',
                page: const BillsScreen(),
              ),
              _NavTile(
                icon: Icons.savings_outlined,
                title: 'Metas',
                subtitle: 'Cofrinhos e objetivos de economia',
                page: const GoalsScreen(),
              ),
              _NavTile(
                icon: Icons.bar_chart,
                title: 'Relatórios',
                subtitle: 'Comparativos, médias e maiores gastos',
                page: const ReportsScreen(),
              ),
              _NavTile(
                icon: Icons.label_outline,
                title: 'Categorias',
                subtitle: 'Criar e editar categorias',
                page: const CategoriesScreen(),
              ),
            ],
          ),

          // ---------- Privacidade ----------
          _SectionCard(
            title: 'Privacidade e segurança',
            icon: Icons.lock_outline,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.hideAmounts,
                onChanged: settings.setHideAmounts,
                title: const Text('Ocultar valores'),
                subtitle: const Text(
                    'Esconde saldos e valores na tela (útil em público).'),
                secondary: Icon(settings.hideAmounts
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.lockEnabled,
                onChanged: (v) async {
                  if (v) {
                    await showPinSetupDialog(context);
                  } else {
                    await settings.disableLock();
                  }
                },
                title: const Text('Bloqueio por PIN'),
                subtitle: const Text('Pede um PIN de 4 dígitos ao abrir o app.'),
                secondary: const Icon(Icons.pin_outlined),
              ),
              if (settings.lockEnabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Alterar PIN'),
                  onTap: () => showPinSetupDialog(context),
                ),
            ],
          ),

          // ---------- Dados ----------
          _SectionCard(
            title: 'Dados',
            icon: Icons.storage_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share),
                title: const Text('Exportar transações (CSV)'),
                subtitle: const Text('Gera uma planilha para backup ou Excel.'),
                onTap: () => _exportCsv(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Apagar todos os dados'),
                subtitle: const Text(
                    'Remove transações, contas e orçamentos e recria os padrões.'),
                onTap: () => _confirmReset(context),
              ),
            ],
          ),

          // ---------- Atualizações ----------
          _SectionCard(
            title: 'Atualizações',
            icon: Icons.system_update,
            children: [
              FutureBuilder<String>(
                future: UpdateService.currentVersion(),
                builder: (context, snap) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_outlined),
                  title: const Text('Verificar atualizações'),
                  subtitle: Text('Versão atual: ${snap.data ?? '...'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => checkForUpdates(context),
                ),
              ),
            ],
          ),

          // ---------- Sobre ----------
          _SectionCard(
            title: 'Sobre',
            icon: Icons.info_outline,
            children: [
              FutureBuilder<String>(
                future: UpdateService.currentVersion(),
                builder: (context, snap) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Finanças'),
                  subtitle: Text(
                      'Versão ${snap.data ?? '...'} • dados locais, sem nuvem'),
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flutter_dash),
                title: Text('Feito com Flutter'),
                subtitle: Text('Roda em Android e PC com a mesma base.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await context.read<FinanceProvider>().exportCsv();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final file = File(p.join(dir.path, 'financas_$stamp.csv'));
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Backup Finanças', text: 'Exportação de transações');
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar.')),
      );
    }
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar todos os dados?'),
        content: const Text(
            'Todas as transações, contas e orçamentos serão removidos e os '
            'dados padrão recriados. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await context.read<FinanceProvider>().resetAll();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados apagados.')),
                );
              }
            },
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cor de destaque',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
