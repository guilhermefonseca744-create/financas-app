import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/finance_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(Fmt.month(provider.selectedMonth),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Resumo do mês
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Receitas',
                  value: Fmt.money(provider.income),
                  color: AppTheme.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Despesas',
                  value: Fmt.money(provider.expense),
                  color: AppTheme.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<double>(
            future: provider.dailyAverageExpense(),
            builder: (context, snap) => _StatCard(
              label: 'Média de gastos por dia',
              value: Fmt.money(snap.data ?? 0),
              color: Theme.of(context).colorScheme.primary,
              wide: true,
            ),
          ),
          const SizedBox(height: 20),

          // Evolução
          Text('Evolução (6 meses)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _MonthlyComparison(provider: provider),
          const SizedBox(height: 20),

          // Top categorias
          Text('Maiores gastos por categoria',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _TopCategories(provider: provider),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: wide ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _MonthlyComparison extends StatelessWidget {
  const _MonthlyComparison({required this.provider});
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
                height: 200, child: Center(child: CircularProgressIndicator())),
          );
        }
        final data = snapshot.data!;
        final maxVal = data.fold<double>(
            1,
            (m, e) =>
                [m, e.income, e.expense].reduce((a, b) => a > b ? a : b));
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.2,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(Fmt.month(data[i].month).substring(0, 3),
                                style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < data.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                            toY: data[i].income,
                            color: AppTheme.income,
                            width: 8,
                            borderRadius: BorderRadius.circular(2)),
                        BarChartRodData(
                            toY: data[i].expense,
                            color: AppTheme.expense,
                            width: 8,
                            borderRadius: BorderRadius.circular(2)),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopCategories extends StatelessWidget {
  const _TopCategories({required this.provider});
  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final data = provider.expenseByCategory;
    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sem gastos neste mês.')),
        ),
      );
    }
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final e in entries.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(provider.categoryById(e.key)?.icon ?? Icons.label,
                            size: 18,
                            color: provider.categoryById(e.key)?.color),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                provider.categoryById(e.key)?.name ?? '—')),
                        Text(Fmt.money(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: max <= 0 ? 0 : e.value / max,
                        minHeight: 6,
                        color: provider.categoryById(e.key)?.color,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
