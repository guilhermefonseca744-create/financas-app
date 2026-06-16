import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/database.dart';
import 'data/finance_repository.dart';
import 'state/finance_provider.dart';
import 'state/settings_controller.dart';
import 'ui/screens/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  final db = await openAppDatabase();
  final repo = FinanceRepository(db);
  final provider = FinanceProvider(repo);
  await provider.init();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs)..load();

  runApp(FinancasApp(provider: provider, settings: settings));
}

class FinancasApp extends StatelessWidget {
  const FinancasApp({
    super.key,
    required this.provider,
    required this.settings,
  });

  final FinanceProvider provider;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Finanças',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(settings.seedColor),
          darkTheme: AppTheme.dark(settings.seedColor),
          themeMode: settings.themeMode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppGate(),
        ),
      ),
    );
  }
}
