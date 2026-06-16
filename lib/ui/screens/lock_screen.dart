import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import '../home_shell.dart';

/// Decide se mostra a tela de bloqueio (PIN) ou o app.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    if (!settings.lockEnabled || _unlocked) {
      return const HomeShell();
    }
    return LockScreen(onUnlock: () => setState(() => _unlocked = true));
  }
}

/// Tela de PIN para destravar o app.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _error = false);
    if (v.length == 4) {
      final ok = context.read<SettingsController>().verifyPin(v);
      if (ok) {
        widget.onUnlock();
      } else {
        setState(() => _error = true);
        _controller.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Digite seu PIN',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  style: const TextStyle(fontSize: 28, letterSpacing: 12),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: _error ? 'PIN incorreto' : null,
                  ),
                  onChanged: _onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo para criar/alterar o PIN (digita duas vezes).
Future<void> showPinSetupDialog(BuildContext context) async {
  final settings = context.read<SettingsController>();
  final first = TextEditingController();
  final second = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Definir PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Novo PIN (4 dígitos)', counterText: ''),
              ),
              TextField(
                controller: second,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirmar PIN',
                  counterText: '',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (first.text.length != 4) {
                  setState(() => error = 'Use 4 dígitos');
                  return;
                }
                if (first.text != second.text) {
                  setState(() => error = 'Os PINs não coincidem');
                  return;
                }
                await settings.setPin(first.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    },
  );
}
