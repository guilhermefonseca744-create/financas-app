// Testes de integração do FinanceRepository contra um SQLite em memória (FFI).
// Provam a lógica de dados de ponta a ponta sem precisar da UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:financas_app/data/database.dart';
import 'package:financas_app/data/finance_repository.dart';
import 'package:financas_app/data/models.dart';

void main() {
  late Database db;
  late FinanceRepository repo;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: createAppSchema,
      ),
    );
    repo = FinanceRepository(db);
  });

  tearDown(() => db.close());

  test('seed cria conta Carteira e categorias de receita/despesa', () async {
    final accounts = await repo.getAccounts();
    expect(accounts.length, 1);
    expect(accounts.first.name, 'Carteira');

    final cats = await repo.getCategories();
    expect(cats.any((c) => c.type == TxType.expense), isTrue);
    expect(cats.any((c) => c.type == TxType.income), isTrue);
  });

  test('saldo reflete receita menos despesa', () async {
    final accId = (await repo.getAccounts()).first.id!;
    final cats = await repo.getCategories();
    final incomeCat = cats.firstWhere((c) => c.type == TxType.income).id!;
    final expenseCat = cats.firstWhere((c) => c.type == TxType.expense).id!;
    final now = DateTime.now();

    await repo.insertTx(Tx(
        type: TxType.income,
        amount: 1000,
        description: 'Salário',
        date: now,
        accountId: accId,
        categoryId: incomeCat));
    await repo.insertTx(Tx(
        type: TxType.expense,
        amount: 250,
        description: 'Mercado',
        date: now,
        accountId: accId,
        categoryId: expenseCat));

    expect(await repo.balanceOf(accId), 750);
    expect(await repo.totalByType(TxType.income, now), 1000);
    expect(await repo.totalByType(TxType.expense, now), 250);
  });

  test('transferência move saldo entre contas', () async {
    final origem = (await repo.getAccounts()).first.id!;
    final destino = await repo.insertAccount(const Account(
      name: 'Banco',
      type: AccountType.bank,
      initialBalance: 500,
      colorValue: 0xFF000000,
    ));
    final now = DateTime.now();

    // Transfere 200 de "Banco" (500) para "Carteira" (0).
    await repo.insertTx(Tx(
        type: TxType.transfer,
        amount: 200,
        description: '',
        date: now,
        accountId: destino,
        toAccountId: origem));

    expect(await repo.balanceOf(origem), 200); // recebeu
    expect(await repo.balanceOf(destino), 300); // 500 - 200
  });

  test('expenseByCategory agrupa e soma gastos por categoria', () async {
    final accId = (await repo.getAccounts()).first.id!;
    final expenseCats =
        (await repo.getCategories()).where((c) => c.type == TxType.expense).toList();
    final c1 = expenseCats[0].id!;
    final c2 = expenseCats[1].id!;
    final now = DateTime.now();

    for (final amount in [100.0, 50.0]) {
      await repo.insertTx(Tx(
          type: TxType.expense,
          amount: amount,
          description: '',
          date: now,
          accountId: accId,
          categoryId: c1));
    }
    await repo.insertTx(Tx(
        type: TxType.expense,
        amount: 30,
        description: '',
        date: now,
        accountId: accId,
        categoryId: c2));

    final byCat = await repo.expenseByCategory(now);
    expect(byCat[c1], 150);
    expect(byCat[c2], 30);
  });

  test('orçamento faz upsert (substitui valor do mesmo mês)', () async {
    final cat = (await repo.getCategories())
        .firstWhere((c) => c.type == TxType.expense)
        .id!;

    await repo.upsertBudget(Budget(categoryId: cat, amount: 500, month: '2026-06'));
    await repo.upsertBudget(Budget(categoryId: cat, amount: 800, month: '2026-06'));

    final budgets = await repo.getBudgets('2026-06');
    expect(budgets.length, 1);
    expect(budgets.first.amount, 800);
  });
}
