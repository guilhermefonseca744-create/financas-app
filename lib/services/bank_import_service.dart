import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../data/models.dart';

/// Registro cru de uma notificação recebida (para diagnóstico).
class NotifLog {
  final String source;
  final String title;
  final String content;
  final DateTime time;
  final bool matched;
  const NotifLog(
      this.source, this.title, this.content, this.time, this.matched);
}

/// Extrai valor e estabelecimento do texto de uma notificação de banco.
class BankParser {
  /// Palavras que indicam que a notificação é de uma compra/gasto.
  static final RegExp _purchase = RegExp(
    r'compra|aprovad|d[eé]bito|pagamento|cart[ãa]o|gasto|despesa|transa[çc][ãa]o',
    caseSensitive: false,
  );

  static final RegExp _money = RegExp(
    r'R\$\s*([\d.]*\d(?:,\d{2})?)',
    caseSensitive: false,
  );

  // Captura o que vem depois de "em/no/na/para" (nome do estabelecimento).
  static final RegExp _merchant = RegExp(
    r'(?:\bem|\bno|\bna|\bpara)\s+([A-Za-zÀ-ÿ0-9][\w À-ÿ\*\.\-&/]{2,40})',
    caseSensitive: false,
  );

  static bool looksLikePurchase(String text) =>
      text.contains(RegExp(r'R\$')) && _purchase.hasMatch(text);

  static ({double? amount, String? merchant}) parse(String text) {
    double? amount;
    final m = _money.firstMatch(text);
    if (m != null) {
      final raw = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      amount = double.tryParse(raw);
    }

    String? merchant;
    final mm = _merchant.firstMatch(text);
    if (mm != null) {
      merchant = mm.group(1)!.trim();
      // Remove rabichos comuns no fim ("em 12/06", "às 10h").
      merchant = merchant
          .replaceAll(RegExp(r'\s+(em|às|as)\s.*$', caseSensitive: false), '')
          .trim();
      if (merchant.isEmpty) merchant = null;
    }

    return (amount: amount, merchant: merchant);
  }
}

/// Escuta as notificações do sistema e captura possíveis compras.
class BankImportService {
  static StreamSubscription<ServiceNotificationEvent>? _sub;

  /// Últimas notificações recebidas (diagnóstico). Reativo para a UI.
  static final ValueNotifier<List<NotifLog>> recent =
      ValueNotifier<List<NotifLog>>([]);

  /// Indica se a escuta está ativa.
  static final ValueNotifier<bool> listening = ValueNotifier<bool>(false);

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    return NotificationListenerService.isPermissionGranted();
  }

  /// Abre as configurações do Android para o usuário conceder acesso.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return NotificationListenerService.requestPermission();
  }

  /// Começa a escutar. [onCapture] é chamado para cada compra detectada.
  static Future<void> start(void Function(PendingImport) onCapture) async {
    if (!isSupported) return;
    if (!await isPermissionGranted()) return;
    if (_sub != null) return;
    _sub = NotificationListenerService.notificationsStream.listen((event) {
      final title = event.title ?? '';
      final content = event.content ?? '';
      final text = '$title $content';
      final matched =
          BankParser.looksLikePurchase(text) && BankParser.parse(text).amount != null;

      // Diagnóstico: registra TODA notificação recebida (últimas 30).
      final log = [
        NotifLog(event.packageName ?? '', title, content, DateTime.now(),
            matched),
        ...recent.value,
      ];
      recent.value = log.take(30).toList();

      if (!matched) return;
      final parsed = BankParser.parse(text);
      onCapture(PendingImport(
        source: event.packageName ?? '',
        title: title,
        rawText: content.isEmpty ? title : content,
        amount: parsed.amount,
        merchant: parsed.merchant,
        createdAt: DateTime.now(),
      ));
    });
    listening.value = true;
  }

  /// Reinicia a escuta (cancela e assina de novo).
  static Future<void> restart(void Function(PendingImport) onCapture) async {
    stop();
    await start(onCapture);
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    listening.value = false;
  }
}
