import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/finance_provider.dart';
import 'update_flow.dart';
import 'screens/accounts_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/transaction_editor.dart';

/// Casca de navegação responsiva:
/// - telas largas (PC): NavigationRail à esquerda;
/// - telas estreitas (Android): NavigationBar embaixo.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Verificação silenciosa de atualização ao abrir o app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkForUpdates(context, silent: true);
    });
  }

  static const _destinations = <_Dest>[
    _Dest('Início', Icons.dashboard_outlined, Icons.dashboard),
    _Dest('Transações', Icons.swap_vert_outlined, Icons.swap_vert),
    _Dest('Contas', Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet),
    _Dest('Orçamento', Icons.pie_chart_outline, Icons.pie_chart),
    _Dest('Ajustes', Icons.settings_outlined, Icons.settings),
  ];

  final _pages = const [
    DashboardScreen(),
    TransactionsScreen(),
    AccountsScreen(),
    BudgetsScreen(),
    SettingsScreen(),
  ];

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionEditor()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (provider.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FloatingActionButton(
                  onPressed: _openEditor,
                  tooltip: 'Nova transação',
                  child: const Icon(Icons.add),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _pages[_index],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        tooltip: 'Nova transação',
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
