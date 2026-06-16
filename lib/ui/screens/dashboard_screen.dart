import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/finance_provider.dart';
import '../../state/settings_controller.dart';
import '../widgets/month_selector.dart';
import 'bank_import_screen.dart';
import 'bills_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Início',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Builder(builder: (context) {
                  final settings = context.watch<SettingsController>();
                  return IconButton(
                    onPressed: settings.toggleHideAmounts,
                    tooltip: settings.hideAmounts
                        ? 'Mostrar valores'
                        : 'Ocultar valores',
                    icon: Icon(settings.hideAmounts
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            const MonthSelector(),
            const SizedBox(height: 16),
            _BalanceCard(provider: provider),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Receitas',
                    value: provider.income,
                    color: AppTheme.income,
                    icon: Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Despesas',
                    value: provider.expense,
                    color: AppTheme.expense,
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ImportsReminder(provider: provider),
            _BillsReminder(provider: provider),
            const _QuickActions(),
            const SizedBox(height: 20),
            _SectionTitle('Gastos por categoria'),
            const SizedBox(height: 8),
            _ExpensePie(provider: provider),
            const SizedBox(height: 20),
            _SectionTitle('Evolução (6 meses)'),
            const SizedBox(height: 8),
            _MonthlyBars(provider: provider),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.provider});
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final monthResult = provider.monthBalance;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo total (todas as contas)',
                style: TextStyle(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 6),
            Text(
              settings.money(provider.totalBalance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  monthResult >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  'Resultado do mês: ${settings.money(monthResult)}',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportsReminder extends StatelessWidget {
  const _ImportsReminder({required this.provider});
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final count = provider.pendingImports.length;
    if (count == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BankImportScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count compra(s) detectada(s) no banco — toque para revisar',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSecondaryContainer),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BillsReminder extends StatelessWidget {
  const _BillsReminder({required this.provider});
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final pending = provider.pendingBills;
    if (pending.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final overdue = pending.where((b) => now.day > b.dueDay).toList();
    final scheme = Theme.of(context).colorScheme;
    final total = pending.fold<double>(0, (s, b) => s + b.amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: overdue.isNotEmpty
            ? scheme.errorContainer
            : scheme.tertiaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BillsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  overdue.isNotEmpty
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_outlined,
                  color: overdue.isNotEmpty
                      ? scheme.onErrorContainer
                      : scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overdue.isNotEmpty
                            ? '${overdue.length} conta(s) vencida(s)'
                            : '${pending.length} conta(s) a pagar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: overdue.isNotEmpty
                              ? scheme.onErrorContainer
                              : scheme.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        'Total ${Fmt.money(total)}',
                        style: TextStyle(
                          color: overdue.isNotEmpty
                              ? scheme.onErrorContainer
                              : scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: overdue.isNotEmpty
                        ? scheme.onErrorContainer
                        : scheme.onTertiaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, Widget)>[
      (Icons.bar_chart, 'Relatórios', const ReportsScreen()),
      (Icons.savings_outlined, 'Metas', const GoalsScreen()),
      (Icons.repeat, 'Recorrentes', const RecurringScreen()),
      (Icons.notifications_outlined, 'Contas', const BillsScreen()),
    ];
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => a.$3)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(a.$1,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer),
                    ),
                    const SizedBox(height: 6),
                    Text(a.$2,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Semantics(
      label: '$label: ${settings.money(value)}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                settings.money(value),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _ExpensePie extends StatelessWidget {
  const _ExpensePie({required this.provider});
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final data = provider.expenseByCategory;
    if (data.isEmpty) {
      return const _EmptyHint('Sem despesas neste mês ainda.');
    }
    final total = data.values.fold(0.0, (a, b) => a + b);
    final entries = data.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value,
                        color: provider.categoryById(e.key)?.color ??
                            Colors.grey,
                        title:
                            '${(e.value / total * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legenda em texto (acessível, não depende só de cor).
            ...entries.map((e) {
              final cat = provider.categoryById(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: cat?.color ?? Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cat?.name ?? 'Sem categoria')),
                    Text(Fmt.money(e.value),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.provider});
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        List<({DateTime month, double income, double expense})>>(
      future: provider.monthlyTotals(6),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final data = snapshot.data!;
        final maxVal = data.fold<double>(
            1,
            (m, e) => [m, e.income, e.expense]
                .reduce((a, b) => a > b ? a : b));

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: maxVal * 1.2,
                      barTouchData: BarTouchData(enabled: true),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= data.length) {
                                return const SizedBox.shrink();
                              }
                              final m = data[i].month;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  Fmt.month(m).substring(0, 3),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < data.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: data[i].income,
                                color: AppTheme.income,
                                width: 8,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              BarChartRodData(
                                toY: data[i].expense,
                                color: AppTheme.expense,
                                width: 8,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _LegendDot(color: AppTheme.income, label: 'Receitas'),
                    SizedBox(width: 20),
                    _LegendDot(color: AppTheme.expense, label: 'Despesas'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
}
