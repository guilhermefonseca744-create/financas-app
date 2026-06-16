import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../services/update_service.dart';

/// Verifica atualizações e conduz o usuário pelo download/instalação.
/// [silent] = true não mostra "já está atualizado" nem erros (uso no início).
Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!AppConfig.updatesConfigured) {
    if (!silent) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Atualização ainda não configurada (defina o repositório no código).'),
      ));
    }
    return;
  }

  UpdateInfo? info;
  try {
    info = await UpdateService.check();
  } catch (e) {
    if (!silent) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível verificar agora.')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  if (info == null) {
    if (!silent) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Você já está na última versão. 🎉')),
      );
    }
    return;
  }

  final update = info;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Atualização disponível (${update.version})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Você tem a versão ${update.currentVersion}.'),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Novidades:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(update.notes),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Atualizar')),
      ],
    ),
  );

  if (go != true || !context.mounted) return;
  await _downloadWithProgress(context, update);
}

Future<void> _downloadWithProgress(
    BuildContext context, UpdateInfo info) async {
  final progress = ValueNotifier<double>(0);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Baixando atualização'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: value == 0 ? null : value),
            const SizedBox(height: 12),
            Text('${(value * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    ),
  );

  try {
    await UpdateService.downloadAndInstall(
      info.url,
      onProgress: (p) => progress.value = p,
    );
    if (context.mounted) Navigator.of(context).pop(); // fecha o progresso
    if (!Platform.isAndroid && context.mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Baixado. No PC, instale pelo arquivo manualmente.'),
      ));
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Falha ao baixar a atualização.')),
    );
  } finally {
    progress.dispose();
  }
}
