import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

/// Acesso a dados: CRUD e agregações de saldo/relatórios.
class FinanceRepository {
  FinanceRepository(this._db);
  final Database _db;

  // ---------- Contas ----------
  Future<List<Account>> getAccounts() async {
    final rows = await _db.query('accounts', orderBy: 'id');
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account a) =>
      _db.insert('accounts', a.toMap()..remove('id'));

  Future<void> updateAccount(Account a) => _db
      .update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);

  Future<void> deleteAccount(int id) =>
      _db.delete('accounts', where: 'id = ?', whereArgs: [id]);

  /// Saldo atual da conta = saldo inicial + entradas - saídas (inclui transferências).
  Future<double> balanceOf(int accountId) async {
    final acc = (await _db
            .query('accounts', where: 'id = ?', whereArgs: [accountId]))
        .first;
    double balance = (acc['initial_balance'] as num).toDouble();

    final income = await _sum(
        "type='income' AND account_id=?", [accountId]);
    final expense = await _sum(
        "type='expense' AND account_id=?", [accountId]);
    final transferOut = await _sum(
        "type='transfer' AND account_id=?", [accountId]);
    final transferIn = await _sum(
        "type='transfer' AND to_account_id=?", [accountId]);

    return balance + income - expense - transferOut + transferIn;
  }

  Future<Map<int, double>> allBalances() async {
    final accounts = await getAccounts();
    final result = <int, double>{};
    for (final a in accounts) {
      result[a.id!] = await balanceOf(a.id!);
    }
    return result;
  }

  Future<double> _sum(String where, List<Object?> args) async {
    final r = await _db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE $where',
        args);
    return (r.first['s'] as num).toDouble();
  }

  // ---------- Categorias ----------
  Future<List<Category>> getCategories() async {
    final rows = await _db.query('categories', orderBy: 'name');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) =>
      _db.insert('categories', c.toMap()..remove('id'));

  Future<void> updateCategory(Category c) => _db
      .update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteCategory(int id) =>
      _db.delete('categories', where: 'id = ?', whereArgs: [id]);

  // ---------- Transações ----------
  Future<List<Tx>> getTransactions({DateTime? month}) async {
    String? where;
    List<Object?>? args;
    if (month != null) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      where = 'date >= ? AND date < ?';
      args = [start.toIso8601String(), end.toIso8601String()];
    }
    final rows = await _db.query('transactions',
        where: where, whereArgs: args, orderBy: 'date DESC, id DESC');
    return rows.map(Tx.fromMap).toList();
  }

  Future<int> insertTx(Tx t) =>
      _db.insert('transactions', t.toMap()..remove('id'));

  Future<void> updateTx(Tx t) => _db
      .update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTx(int id) =>
      _db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  // ---------- Relatórios ----------
  /// Total por tipo no mês.
  Future<double> totalByType(TxType type, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return _sum("type=? AND date >= ? AND date < ?",
        [type.db, start.toIso8601String(), end.toIso8601String()]);
  }

  /// Gastos agrupados por categoria no mês (para gráfico de pizza).
  Future<Map<int, double>> expenseByCategory(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await _db.rawQuery('''
      SELECT category_id, SUM(amount) AS s
      FROM transactions
      WHERE type='expense' AND category_id IS NOT NULL
        AND date >= ? AND date < ?
      GROUP BY category_id
      ORDER BY s DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return {
      for (final r in rows)
        r['category_id'] as int: (r['s'] as num).toDouble()
    };
  }

  /// Total gasto/recebido por mês nos últimos [count] meses (para gráfico de barras).
  Future<List<({DateTime month, double income, double expense})>>
      monthlyTotals(int count) async {
    final now = DateTime.now();
    final result = <({DateTime month, double income, double expense})>[];
    for (int i = count - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      result.add((
        month: m,
        income: await totalByType(TxType.income, m),
        expense: await totalByType(TxType.expense, m),
      ));
    }
    return result;
  }

  // ---------- Orçamentos ----------
  Future<List<Budget>> getBudgets(String monthKey) async {
    final rows = await _db
        .query('budgets', where: 'month = ?', whereArgs: [monthKey]);
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> upsertBudget(Budget b) async {
    await _db.insert('budgets', b.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBudget(int categoryId, String monthKey) => _db.delete(
      'budgets',
      where: 'category_id = ? AND month = ?',
      whereArgs: [categoryId, monthKey]);

  // ---------- Busca de transações ----------
  /// Busca transações com filtros opcionais (texto, categoria, conta, tipo).
  Future<List<Tx>> searchTransactions({
    DateTime? month,
    String? query,
    int? categoryId,
    int? accountId,
    TxType? type,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (month != null) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      where.add('date >= ? AND date < ?');
      args..add(start.toIso8601String())..add(end.toIso8601String());
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('description LIKE ?');
      args.add('%${query.trim()}%');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (accountId != null) {
      where.add('(account_id = ? OR to_account_id = ?)');
      args..add(accountId)..add(accountId);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type.db);
    }
    final rows = await _db.query('transactions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'date DESC, id DESC');
    return rows.map(Tx.fromMap).toList();
  }

  // ---------- Faturas de cartão ----------
  /// Calcula a fatura aberta de um cartão: valor, datas de fechamento e vencimento.
  Future<({double amount, DateTime closeDate, DateTime dueDate})?> invoiceOf(
      Account card) async {
    if (card.type != AccountType.creditCard ||
        card.closingDay == null ||
        card.dueDay == null) {
      return null;
    }
    final now = DateTime.now();
    final closingDay = card.closingDay!;
    // Fechamento do ciclo atual.
    DateTime close;
    if (now.day <= closingDay) {
      close = DateTime(now.year, now.month, closingDay);
    } else {
      close = DateTime(now.year, now.month + 1, closingDay);
    }
    final openStart = DateTime(close.year, close.month - 1, closingDay + 1);
    final amount = await _sum(
        "type='expense' AND account_id=? AND date >= ? AND date <= ?",
        [card.id, openStart.toIso8601String(), close.toIso8601String()]);
    final due = DateTime(close.year, close.month, card.dueDay!);
    final dueDate = due.isBefore(close)
        ? DateTime(close.year, close.month + 1, card.dueDay!)
        : due;
    return (amount: amount, closeDate: close, dueDate: dueDate);
  }

  // ---------- Lançamentos recorrentes ----------
  Future<List<Recurring>> getRecurrings() async {
    final rows = await _db.query('recurring', orderBy: 'id');
    return rows.map(Recurring.fromMap).toList();
  }

  Future<int> insertRecurring(Recurring r) =>
      _db.insert('recurring', r.toMap()..remove('id'));

  Future<void> updateRecurring(Recurring r) => _db
      .update('recurring', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<void> deleteRecurring(int id) =>
      _db.delete('recurring', where: 'id = ?', whereArgs: [id]);

  /// Gera as transações dos recorrentes ativos cujo dia já chegou neste mês.
  /// Retorna quantas foram criadas.
  Future<int> generateDueRecurrings() async {
    final now = DateTime.now();
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    int created = 0;
    for (final r in await getRecurrings()) {
      if (!r.active) continue;
      if (r.lastGenerated == monthKey) continue;
      if (now.day < r.dayOfMonth) continue;
      final day = r.dayOfMonth.clamp(1, _daysInMonth(now.year, now.month));
      await insertTx(Tx(
        type: r.type,
        amount: r.amount,
        description: r.description,
        date: DateTime(now.year, now.month, day),
        accountId: r.accountId,
        categoryId: r.categoryId,
      ));
      await _db.update('recurring', {'last_generated': monthKey},
          where: 'id = ?', whereArgs: [r.id]);
      created++;
    }
    return created;
  }

  int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  // ---------- Metas / cofrinhos ----------
  Future<List<Goal>> getGoals() async {
    final rows = await _db.query('goals', orderBy: 'id');
    return rows.map(Goal.fromMap).toList();
  }

  Future<int> insertGoal(Goal g) => _db.insert('goals', g.toMap()..remove('id'));

  Future<void> updateGoal(Goal g) =>
      _db.update('goals', g.toMap(), where: 'id = ?', whereArgs: [g.id]);

  Future<void> deleteGoal(int id) =>
      _db.delete('goals', where: 'id = ?', whereArgs: [id]);

  Future<void> addToGoal(int id, double delta) async {
    await _db.rawUpdate(
        'UPDATE goals SET saved_amount = MAX(0, saved_amount + ?) WHERE id = ?',
        [delta, id]);
  }

  // ---------- Contas a pagar (lembretes) ----------
  Future<List<Bill>> getBills() async {
    final rows = await _db.query('bills', orderBy: 'due_day');
    return rows.map(Bill.fromMap).toList();
  }

  Future<int> insertBill(Bill b) => _db.insert('bills', b.toMap()..remove('id'));

  Future<void> updateBill(Bill b) =>
      _db.update('bills', b.toMap(), where: 'id = ?', whereArgs: [b.id]);

  Future<void> deleteBill(int id) =>
      _db.delete('bills', where: 'id = ?', whereArgs: [id]);

  /// Meses (chave AAAA-MM) em que a conta [billId] foi paga.
  Future<Set<String>> paidMonths(int billId) async {
    final rows = await _db.query('bill_payments',
        where: 'bill_id = ?', whereArgs: [billId]);
    return {for (final r in rows) r['month'] as String};
  }

  /// Marca uma conta como paga no mês e cria a transação de despesa.
  Future<void> payBill(Bill bill, String monthKey, int accountId) async {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = bill.dueDay.clamp(1, _daysInMonth(year, month));
    await insertTx(Tx(
      type: TxType.expense,
      amount: bill.amount,
      description: bill.name,
      date: DateTime(year, month, day),
      accountId: accountId,
      categoryId: bill.categoryId,
    ));
    await _db.insert('bill_payments', {'bill_id': bill.id, 'month': monthKey},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---------- Relatórios avançados ----------
  /// Média diária de despesas no mês corrente.
  Future<double> dailyAverageExpense(DateTime month) async {
    final total = await totalByType(TxType.expense, month);
    final now = DateTime.now();
    final days = (now.year == month.year && now.month == month.month)
        ? now.day
        : _daysInMonth(month.year, month.month);
    return days == 0 ? 0 : total / days;
  }

  // ---------- Exportar ----------
  /// Gera o CSV de todas as transações.
  Future<String> exportCsv() async {
    final txs = await getTransactions();
    final accounts = {for (final a in await getAccounts()) a.id: a.name};
    final cats = {for (final c in await getCategories()) c.id: c.name};
    final sb = StringBuffer('Data,Tipo,Valor,Descrição,Categoria,Conta\n');
    for (final t in txs) {
      final fields = [
        t.date.toIso8601String().split('T').first,
        t.type.label,
        t.amount.toStringAsFixed(2),
        t.description,
        cats[t.categoryId] ?? '',
        accounts[t.accountId] ?? '',
      ].map(_csv).join(',');
      sb.writeln(fields);
    }
    return sb.toString();
  }

  String _csv(String v) =>
      '"${v.replaceAll('"', '""')}"';

  // ---------- Importações do banco (notificações) ----------
  Future<List<PendingImport>> getPendingImports() async {
    final rows =
        await _db.query('pending_imports', orderBy: 'created_at DESC, id DESC');
    return rows.map(PendingImport.fromMap).toList();
  }

  Future<int> insertPendingImport(PendingImport pi) =>
      _db.insert('pending_imports', pi.toMap()..remove('id'));

  Future<void> deletePendingImport(int id) =>
      _db.delete('pending_imports', where: 'id = ?', whereArgs: [id]);

  // ---------- Manutenção ----------
  /// Apaga todos os dados e recria a conta e categorias padrão.
  Future<void> resetAll() async {
    await _db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('accounts');
      await txn.delete('categories');
    });
    await seedDefaults(_db);
  }
}
