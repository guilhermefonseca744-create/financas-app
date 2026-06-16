# 💰 Finanças — Gerenciador de finanças pessoais

App de gerenciamento de finanças do dia a dia para **Android** e **PC** (Windows/Linux/macOS),
feito com **Flutter** e armazenamento **local** (SQLite — funciona offline, dados ficam no dispositivo).

## Funcionalidades (MVP)

- **Receitas e despesas** — registre entradas e saídas com valor, categoria, conta, data e descrição.
- **Transferências** entre contas.
- **Categorias** pré-cadastradas (editáveis) para receitas e despesas.
- **Contas e cartões** — múltiplas carteiras, contas bancárias e cartões de crédito com limite; saldo calculado automaticamente.
- **Orçamento mensal** por categoria, com barra de progresso que alerta quando você ultrapassa o limite.
- **Dashboard** com saldo total, resumo do mês, gráfico de pizza (gastos por categoria) e gráfico de barras (evolução de 6 meses).
- **Interface responsiva**: barra de navegação inferior no celular e barra lateral (NavigationRail) no PC.
- **Acessibilidade**: alto contraste, áreas de toque ≥48dp, rótulos semânticos, suporte a tema claro/escuro do sistema.

## Pré-requisitos

Flutter **não está instalado** nesta máquina. Instale primeiro:

1. Baixe o Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Adicione o `flutter\bin` ao PATH.
3. Verifique a instalação:
   ```powershell
   flutter --version
   flutter doctor
   ```
   Para rodar no **PC com Windows**, o `flutter doctor` precisa apontar o **Visual Studio** com a carga "Desktop development with C++".
   Para rodar no **Android**, precisa do Android Studio + um emulador ou celular com depuração USB.

## Como rodar

No diretório do projeto (`financas-app`):

```powershell
# 1. Gera as pastas de plataforma (android/, windows/, etc.) sem sobrescrever o código já criado
flutter create .

# 2. Baixa as dependências
flutter pub get

# 3a. Rodar no PC (Windows)
flutter run -d windows

# 3b. Rodar no Android (com emulador ou celular conectado)
flutter run -d android
```

> `flutter create .` apenas adiciona os arquivos de plataforma que faltam — ele **não** apaga `lib/`, `pubspec.yaml` nem o `README.md`.

### Gerar instaladores/builds

```powershell
# Os ícones das categorias são carregados dinamicamente do banco, então o
# tree-shaking de ícones precisa ser desativado nos builds de release:
flutter build apk --no-tree-shake-icons          # APK Android
flutter build windows --release --no-tree-shake-icons  # Executável Windows
```

## Estrutura do projeto

```
lib/
├── main.dart                      # Bootstrap: abre o banco, injeta o estado, inicia o app
├── core/
│   ├── formatters.dart            # Formatação de moeda e datas (pt-BR)
│   └── theme.dart                 # Tema (cores AA, claro/escuro, alvos de toque)
├── data/
│   ├── models.dart                # Account, Category, Tx, Budget + enums
│   ├── database.dart              # SQLite (nativo + FFI desktop) e seed inicial
│   └── finance_repository.dart    # CRUD e agregações (saldos, relatórios)
├── state/
│   └── finance_provider.dart      # ChangeNotifier com o estado do app
└── ui/
    ├── home_shell.dart            # Navegação responsiva (rail no PC, bottom bar no celular)
    ├── widgets/
    │   └── month_selector.dart    # Seletor de mês
    └── screens/
        ├── dashboard_screen.dart      # Resumo + gráficos
        ├── transactions_screen.dart   # Lista de transações
        ├── accounts_screen.dart       # Contas/cartões + editor
        ├── budgets_screen.dart        # Orçamentos por categoria
        └── transaction_editor.dart    # Formulário de transação
```

## Arquitetura

`UI → FinanceProvider (estado) → FinanceRepository (queries) → SQLite`

Os dados nunca saem do dispositivo. Como escolhido, **não há sincronização em nuvem** nesta versão — pode ser adicionada depois sem reescrever a base (o repositório isola o acesso a dados).
