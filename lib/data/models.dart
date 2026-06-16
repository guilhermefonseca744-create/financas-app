import 'package:flutter/material.dart';

/// Tipo de movimentação financeira.
enum TxType { income, expense, transfer }

extension TxTypeX on TxType {
  String get label => switch (this) {
        TxType.income => 'Receita',
        TxType.expense => 'Despesa',
        TxType.transfer => 'Transferência',
      };

  String get db => name; // 'income' | 'expense' | 'transfer'

  static TxType fromDb(String v) =>
      TxType.values.firstWhere((e) => e.name == v, orElse: () => TxType.expense);
}

/// Tipo de conta/carteira.
enum AccountType { cash, bank, creditCard }

extension AccountTypeX on AccountType {
  String get label => switch (this) {
        AccountType.cash => 'Dinheiro',
        AccountType.bank => 'Conta bancária',
        AccountType.creditCard => 'Cartão de crédito',
      };

  String get db => name;

  IconData get icon => switch (this) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.creditCard => Icons.credit_card_outlined,
      };

  static AccountType fromDb(String v) => AccountType.values
      .firstWhere((e) => e.name == v, orElse: () => AccountType.cash);
}

/// Conta ou carteira do usuário.
class Account {
  final int? id;
  final String name;
  final AccountType type;
  final double initialBalance;
  final double? creditLimit; // apenas cartão de crédito
  final int? closingDay; // dia de fechamento da fatura (cartão)
  final int? dueDay; // dia de vencimento da fatura (cartão)
  final int colorValue;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.creditLimit,
    this.closingDay,
    this.dueDay,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    double? initialBalance,
    double? creditLimit,
    int? closingDay,
    int? dueDay,
    int? colorValue,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        initialBalance: initialBalance ?? this.initialBalance,
        creditLimit: creditLimit ?? this.creditLimit,
        closingDay: closingDay ?? this.closingDay,
        dueDay: dueDay ?? this.dueDay,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.db,
        'initial_balance': initialBalance,
        'credit_limit': creditLimit,
        'closing_day': closingDay,
        'due_day': dueDay,
        'color': colorValue,
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: AccountTypeX.fromDb(m['type'] as String),
        initialBalance: (m['initial_balance'] as num?)?.toDouble() ?? 0,
        creditLimit: (m['credit_limit'] as num?)?.toDouble(),
        closingDay: m['closing_day'] as int?,
        dueDay: m['due_day'] as int?,
        colorValue: m['color'] as int,
      );
}

/// Categoria de receita ou despesa.
class Category {
  final int? id;
  final String name;
  final TxType type; // income ou expense
  final int iconCode;
  final int colorValue;

  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  Category copyWith({
    int? id,
    String? name,
    TxType? type,
    int? iconCode,
    int? colorValue,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        iconCode: iconCode ?? this.iconCode,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.db,
        'icon': iconCode,
        'color': colorValue,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: TxTypeX.fromDb(m['type'] as String),
        iconCode: m['icon'] as int,
        colorValue: m['color'] as int,
      );
}

/// Movimentação (receita, despesa ou transferência).
class Tx {
  final int? id;
  final TxType type;
  final double amount;
  final String description;
  final DateTime date;
  final int accountId;
  final int? categoryId; // nulo em transferências
  final int? toAccountId; // destino em transferências
  final String? installmentGroup; // agrupa parcelas de uma compra
  final int? installmentIndex; // nº da parcela (1..total)
  final int? installmentTotal; // total de parcelas
  final String? receiptPath; // caminho da foto do recibo

  const Tx({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.accountId,
    this.categoryId,
    this.toAccountId,
    this.installmentGroup,
    this.installmentIndex,
    this.installmentTotal,
    this.receiptPath,
  });

  Tx copyWith({
    int? id,
    TxType? type,
    double? amount,
    String? description,
    DateTime? date,
    int? accountId,
    int? categoryId,
    int? toAccountId,
    String? installmentGroup,
    int? installmentIndex,
    int? installmentTotal,
    String? receiptPath,
  }) =>
      Tx(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        date: date ?? this.date,
        accountId: accountId ?? this.accountId,
        categoryId: categoryId ?? this.categoryId,
        toAccountId: toAccountId ?? this.toAccountId,
        installmentGroup: installmentGroup ?? this.installmentGroup,
        installmentIndex: installmentIndex ?? this.installmentIndex,
        installmentTotal: installmentTotal ?? this.installmentTotal,
        receiptPath: receiptPath ?? this.receiptPath,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.db,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
        'account_id': accountId,
        'category_id': categoryId,
        'to_account_id': toAccountId,
        'installment_group': installmentGroup,
        'installment_index': installmentIndex,
        'installment_total': installmentTotal,
        'receipt_path': receiptPath,
      };

  factory Tx.fromMap(Map<String, Object?> m) => Tx(
        id: m['id'] as int?,
        type: TxTypeX.fromDb(m['type'] as String),
        amount: (m['amount'] as num).toDouble(),
        description: (m['description'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
        accountId: m['account_id'] as int,
        categoryId: m['category_id'] as int?,
        toAccountId: m['to_account_id'] as int?,
        installmentGroup: m['installment_group'] as String?,
        installmentIndex: m['installment_index'] as int?,
        installmentTotal: m['installment_total'] as int?,
        receiptPath: m['receipt_path'] as String?,
      );
}

/// Orçamento mensal por categoria.
class Budget {
  final int? id;
  final int categoryId;
  final double amount;
  final String month; // 'AAAA-MM'

  const Budget({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.month,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'category_id': categoryId,
        'amount': amount,
        'month': month,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int?,
        categoryId: m['category_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        month: m['month'] as String,
      );
}

/// Lançamento recorrente (salário, assinaturas...). Gera transações automaticamente.
class Recurring {
  final int? id;
  final TxType type; // income ou expense
  final double amount;
  final String description;
  final int accountId;
  final int? categoryId;
  final int dayOfMonth; // dia do mês em que ocorre
  final bool active;
  final String? lastGenerated; // 'AAAA-MM' do último lançamento gerado

  const Recurring({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.accountId,
    this.categoryId,
    required this.dayOfMonth,
    this.active = true,
    this.lastGenerated,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.db,
        'amount': amount,
        'description': description,
        'account_id': accountId,
        'category_id': categoryId,
        'day_of_month': dayOfMonth,
        'active': active ? 1 : 0,
        'last_generated': lastGenerated,
      };

  factory Recurring.fromMap(Map<String, Object?> m) => Recurring(
        id: m['id'] as int?,
        type: TxTypeX.fromDb(m['type'] as String),
        amount: (m['amount'] as num).toDouble(),
        description: (m['description'] as String?) ?? '',
        accountId: m['account_id'] as int,
        categoryId: m['category_id'] as int?,
        dayOfMonth: m['day_of_month'] as int,
        active: (m['active'] as int? ?? 1) == 1,
        lastGenerated: m['last_generated'] as String?,
      );
}

/// Meta de economia (cofrinho).
class Goal {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final int colorValue;
  final int iconCode;

  const Goal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    required this.colorValue,
    required this.iconCode,
  });

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'color': colorValue,
        'icon': iconCode,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int?,
        name: m['name'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        savedAmount: (m['saved_amount'] as num?)?.toDouble() ?? 0,
        colorValue: m['color'] as int,
        iconCode: m['icon'] as int,
      );
}

/// Conta a pagar (lembrete). Vence todo mês no dia [dueDay].
class Bill {
  final int? id;
  final String name;
  final double amount;
  final int dueDay; // 1..31
  final int? categoryId;
  final int? accountId;
  final bool active;

  const Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    this.categoryId,
    this.accountId,
    this.active = true,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'due_day': dueDay,
        'category_id': categoryId,
        'account_id': accountId,
        'active': active ? 1 : 0,
      };

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: m['id'] as int?,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        dueDay: m['due_day'] as int,
        categoryId: m['category_id'] as int?,
        accountId: m['account_id'] as int?,
        active: (m['active'] as int? ?? 1) == 1,
      );
}
