import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inicializa o backend correto do SQLite conforme a plataforma.
/// - Android/iOS: sqflite nativo.
/// - Windows/Linux/macOS: sqflite_common_ffi.
Future<Database> openAppDatabase() async {
  late final String dbPath;

  final bool isDesktop = !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    dbPath = p.join(dir.path, 'financas.db');
  } else {
    dbPath = p.join(await getDatabasesPath(), 'financas.db');
  }

  return databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: createAppSchema,
      onUpgrade: _onUpgrade,
    ),
  );
}

/// Cria o schema e popula os dados iniciais. Público para uso em testes.
Future<void> createAppSchema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      initial_balance REAL NOT NULL DEFAULT 0,
      credit_limit REAL,
      closing_day INTEGER,
      due_day INTEGER,
      color INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      icon INTEGER NOT NULL,
      color INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT,
      date TEXT NOT NULL,
      account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      to_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
      installment_group TEXT,
      installment_index INTEGER,
      installment_total INTEGER,
      receipt_path TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      month TEXT NOT NULL,
      UNIQUE(category_id, month)
    )
  ''');

  await _createV2Tables(db);
  await _createV3Tables(db);

  await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
  await db.execute('CREATE INDEX idx_tx_account ON transactions(account_id)');

  await seedDefaults(db);
}

/// Tabelas adicionadas na versão 2 (recorrentes, metas, contas a pagar).
Future<void> _createV2Tables(Database db) async {
  await db.execute('''
    CREATE TABLE recurring (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT,
      account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      day_of_month INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      last_generated TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      saved_amount REAL NOT NULL DEFAULT 0,
      color INTEGER NOT NULL,
      icon INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      due_day INTEGER NOT NULL,
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');

  await db.execute('''
    CREATE TABLE bill_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      month TEXT NOT NULL,
      UNIQUE(bill_id, month)
    )
  ''');
}

/// Tabela adicionada na versão 3 (importações do banco via notificação).
Future<void> _createV3Tables(Database db) async {
  await db.execute('''
    CREATE TABLE pending_imports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT,
      title TEXT,
      raw_text TEXT,
      amount REAL,
      merchant TEXT,
      created_at TEXT NOT NULL
    )
  ''');
}

/// Migração de versões anteriores.
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE accounts ADD COLUMN closing_day INTEGER');
    await db.execute('ALTER TABLE accounts ADD COLUMN due_day INTEGER');
    await db
        .execute('ALTER TABLE transactions ADD COLUMN installment_group TEXT');
    await db.execute(
        'ALTER TABLE transactions ADD COLUMN installment_index INTEGER');
    await db.execute(
        'ALTER TABLE transactions ADD COLUMN installment_total INTEGER');
    await db.execute('ALTER TABLE transactions ADD COLUMN receipt_path TEXT');
    await _createV2Tables(db);
  }
  if (oldVersion < 3) {
    await _createV3Tables(db);
  }
}

/// Dados iniciais para o app não começar vazio. Público para reuso no reset.
Future<void> seedDefaults(Database db) async {
  // Conta padrão: dinheiro/carteira.
  await db.insert('accounts', {
    'name': 'Carteira',
    'type': 'cash',
    'initial_balance': 0,
    'color': Colors.green.shade600.value,
  });

  const expenses = <List<Object>>[
    ['Alimentação', Icons.restaurant, 0xFFEF5350],
    ['Transporte', Icons.directions_bus, 0xFF42A5F5],
    ['Moradia', Icons.home, 0xFF7E57C2],
    ['Lazer', Icons.movie, 0xFFFFA726],
    ['Saúde', Icons.favorite, 0xFFEC407A],
    ['Mercado', Icons.shopping_cart, 0xFF26A69A],
    ['Contas', Icons.receipt_long, 0xFF8D6E63],
    ['Outros', Icons.category, 0xFF78909C],
  ];

  const incomes = <List<Object>>[
    ['Salário', Icons.work, 0xFF66BB6A],
    ['Freelance', Icons.laptop, 0xFF26C6DA],
    ['Investimentos', Icons.trending_up, 0xFF9CCC65],
    ['Outros', Icons.attach_money, 0xFF78909C],
  ];

  for (final c in expenses) {
    await db.insert('categories', {
      'name': c[0],
      'type': 'expense',
      'icon': (c[1] as IconData).codePoint,
      'color': c[2],
    });
  }
  for (final c in incomes) {
    await db.insert('categories', {
      'name': c[0],
      'type': 'income',
      'icon': (c[1] as IconData).codePoint,
      'color': c[2],
    });
  }
}
