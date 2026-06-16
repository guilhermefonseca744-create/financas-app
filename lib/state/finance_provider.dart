import 'package:flutter/foundation.dart' hide Category;

import '../core/formatters.dart';
import '../data/finance_repository.dart';
import '../data/models.dart';
import '../services/bank_import_service.dart';

/// Estado central do app. Carrega dados do repositório e notifica a UI.
class FinanceProvider extends ChangeNotifier {
  FinanceProvider(this._repo);
  final FinanceRepository _repo;

  bool _loading = true;
  bool get loading => _loading;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get selectedMonth => _selectedMonth;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Tx> _transactions = [];
  Map<int, double> _balances = {};
  Map<int, double> _expenseByCategory = {};
  List<Budget> _budgets = [];
  List<Recurring> _recurrings = [];
  List<Goal> _goals = [];
  List<Bill> _bills = [];
  Set<int> _billsPaidThisMonth = {};
  List<PendingImport> _pendingImports = [];
  double _income = 0;
  double _expense = 0;

  // Filtros da tela de transações.
  String _txQuery = '';
  int? _txCategoryFilter;
  int? _txAccountFilter;
  TxType? _txTypeFilter;

  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == TxType.expense).toList();
  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == TxType.income).toList();
  List<Tx> get transactions => _transactions;
  List<Budget> get budgets => _budgets;
  List<Recurring> get recurrings => _recurrings;
  List<Goal> get goals => _goals;
  List<Bill> get bills => _bills;
  List<PendingImport> get pendingImports => _pendingImports;

  double get income => _income;
  double get expense => _expense;
  double get monthBalance => _income - _expense;
  double get totalBalance => _balances.values.fold(0.0, (sum, v) => sum + v);

  double balanceOf(int accountId) => _balances[accountId] ?? 0;
  Map<int, double> get expenseByCategory => _expenseByCategory;

  // ----- Filtros -----
  String get txQuery => _txQuery;
  int? get txCategoryFilter => _txCategoryFilter;
  int? get txAccountFilter => _txAccountFilter;
  TxType? get txTypeFilter => _txTypeFilter;
  bool get hasActiveFilters =>
      _txQuery.isNotEmpty ||
      _txCategoryFilter != null ||
      _txAccountFilter != null ||
      _txTypeFilter != null;

  void setTxQuery(String q) {
    _txQuery = q;
    notifyListeners();
  }

  void setTxFilters({int? category, int? account, TxType? type}) {
    _txCategoryFilter = category;
    _txAccountFilter = account;
    _txTypeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _txQuery = '';
    _txCategoryFilter = null;
    _txAccountFilter = null;
    _txTypeFilter = null;
    notifyListeners();
  }

  List<Tx> get filteredTransactions {
    return _transactions.where((t) {
      if (_txTypeFilter != null && t.type != _txTypeFilter) return false;
      if (_txCategoryFilter != null && t.categoryId != _txCategoryFilter) {
        return false;
      }
      if (_txAccountFilter != null &&
          t.accountId != _txAccountFilter &&
          t.toAccountId != _txAccountFilter) {
        return false;
      }
      if (_txQuery.isNotEmpty) {
        final q = _txQuery.toLowerCase();
        final cat = categoryById(t.categoryId)?.name.toLowerCase() ?? '';
        if (!t.description.toLowerCase().contains(q) && !cat.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? accountById(int? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Budget? budgetFor(int categoryId) {
    for (final b in _budgets) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  double spentInCategory(int categoryId) => _expenseByCategory[categoryId] ?? 0;

  /// Contas a pagar pendentes neste mês (ativas e ainda não pagas).
  List<Bill> get pendingBills =>
      _bills.where((b) => b.active && !_billsPaidThisMonth.contains(b.id)).toList();

  bool billPaidThisMonth(int billId) => _billsPaidThisMonth.contains(billId);

  Future<({double amount, DateTime closeDate, DateTime dueDate})?> invoiceOf(
          Account card) =>
      _repo.invoiceOf(card);

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await _repo.generateDueRecurrings();
    await _reload();
    _loading = false;
    notifyListeners();
    await startBankImport();
  }

  /// (Re)inicia a escuta de notificações do banco (Android, se permitido).
  Future<void> startBankImport() async {
    await BankImportService.start(_onBankCapture);
  }

  Future<void> _onBankCapture(PendingImport imp) async {
    await _repo.insertPendingImport(imp);
    _pendingImports = await _repo.getPendingImports();
    notifyListeners();
  }

  Future<void> deletePendingImport(int id) async {
    await _repo.deletePendingImport(id);
    _pendingImports = await _repo.getPendingImports();
    notifyListeners();
  }

  Future<void> _reload() async {
    _accounts = await _repo.getAccounts();
    _categories = await _repo.getCategories();
    _transactions = await _repo.getTransactions(month: _selectedMonth);
    _balances = await _repo.allBalances();
    _expenseByCategory = await _repo.expenseByCategory(_selectedMonth);
    _budgets = await _repo.getBudgets(Fmt.monthKey(_selectedMonth));
    _income = await _repo.totalByType(TxType.income, _selectedMonth);
    _expense = await _repo.totalByType(TxType.expense, _selectedMonth);
    _recurrings = await _repo.getRecurrings();
    _goals = await _repo.getGoals();
    _bills = await _repo.getBills();
    final nowKey = Fmt.monthKey(DateTime.now());
    _billsPaidThisMonth = {};
    for (final b in _bills) {
      final paid = await _repo.paidMonths(b.id!);
      if (paid.contains(nowKey)) _billsPaidThisMonth.add(b.id!);
    }
    _pendingImports = await _repo.getPendingImports();
  }

  Future<void> refresh() async {
    await _reload();
    notifyListeners();
  }

  void changeMonth(int delta) {
    _selectedMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    refresh();
  }

  Future<List<({DateTime month, double income, double expense})>>
      monthlyTotals([int count = 6]) => _repo.monthlyTotals(count);

  Future<double> dailyAverageExpense() =>
      _repo.dailyAverageExpense(_selectedMonth);

  Future<String> exportCsv() => _repo.exportCsv();

  // ---------- Transações ----------
  Future<void> addTransaction(Tx t) async {
    await _repo.insertTx(t);
    await refresh();
  }

  Future<void> addTransactions(List<Tx> txs) async {
    for (final t in txs) {
      await _repo.insertTx(t);
    }
    await refresh();
  }

  Future<void> updateTransaction(Tx t) async {
    await _repo.updateTx(t);
    await refresh();
  }

  Future<void> deleteTransaction(int id) async {
    await _repo.deleteTx(id);
    await refresh();
  }

  // ---------- Contas ----------
  Future<void> addAccount(Account a) async {
    await _repo.insertAccount(a);
    await refresh();
  }

  Future<void> updateAccount(Account a) async {
    await _repo.updateAccount(a);
    await refresh();
  }

  Future<void> deleteAccount(int id) async {
    await _repo.deleteAccount(id);
    await refresh();
  }

  // ---------- Categorias ----------
  Future<void> addCategory(Category c) async {
    await _repo.insertCategory(c);
    await refresh();
  }

  Future<void> updateCategory(Category c) async {
    await _repo.updateCategory(c);
    await refresh();
  }

  Future<void> deleteCategory(int id) async {
    await _repo.deleteCategory(id);
    await refresh();
  }

  // ---------- Orçamentos ----------
  Future<void> setBudget(int categoryId, double amount) async {
    await _repo.upsertBudget(Budget(
      categoryId: categoryId,
      amount: amount,
      month: Fmt.monthKey(_selectedMonth),
    ));
    await refresh();
  }

  Future<void> removeBudget(int categoryId) async {
    await _repo.deleteBudget(categoryId, Fmt.monthKey(_selectedMonth));
    await refresh();
  }

  // ---------- Recorrentes ----------
  Future<void> addRecurring(Recurring r) async {
    await _repo.insertRecurring(r);
    await _repo.generateDueRecurrings();
    await refresh();
  }

  Future<void> updateRecurring(Recurring r) async {
    await _repo.updateRecurring(r);
    await refresh();
  }

  Future<void> deleteRecurring(int id) async {
    await _repo.deleteRecurring(id);
    await refresh();
  }

  // ---------- Metas ----------
  Future<void> addGoal(Goal g) async {
    await _repo.insertGoal(g);
    await refresh();
  }

  Future<void> updateGoal(Goal g) async {
    await _repo.updateGoal(g);
    await refresh();
  }

  Future<void> deleteGoal(int id) async {
    await _repo.deleteGoal(id);
    await refresh();
  }

  Future<void> addToGoal(int id, double delta) async {
    await _repo.addToGoal(id, delta);
    await refresh();
  }

  // ---------- Contas a pagar ----------
  Future<void> addBill(Bill b) async {
    await _repo.insertBill(b);
    await refresh();
  }

  Future<void> updateBill(Bill b) async {
    await _repo.updateBill(b);
    await refresh();
  }

  Future<void> deleteBill(int id) async {
    await _repo.deleteBill(id);
    await refresh();
  }

  Future<void> payBill(Bill bill, int accountId) async {
    await _repo.payBill(bill, Fmt.monthKey(DateTime.now()), accountId);
    await refresh();
  }

  Future<void> resetAll() async {
    await _repo.resetAll();
    await refresh();
  }
}
