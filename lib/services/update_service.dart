import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_config.dart';

class UpdateInfo {
  final String version;
  final String currentVersion;
  final String url;
  final String notes;

  UpdateInfo({
    required this.version,
    required this.currentVersion,
    required this.url,
    required this.notes,
  });
}

/// Verifica e instala atualizações a partir das releases do GitHub.
class UpdateService {
  /// Versão atual do app (do pubspec).
  static Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Retorna [UpdateInfo] se houver versão mais nova; `null` se já atualizado.
  /// Lança exceção em caso de erro de rede.
  static Future<UpdateInfo?> check() async {
    if (!AppConfig.updatesConfigured) return null;

    final current = await currentVersion();
    final resp = await http.get(
      AppConfig.latestReleaseApi,
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (resp.statusCode == 404) {
      return null; // ainda não há releases publicadas
    }
    if (resp.statusCode != 200) {
      throw Exception('Erro ao consultar (HTTP ${resp.statusCode}).');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag =
        (data['tag_name'] as String?)?.replaceAll('v', '').trim() ?? '';
    final notes = (data['body'] as String?)?.trim() ?? '';
    final assets = (data['assets'] as List?) ?? const [];

    String? apkUrl;
    for (final a in assets) {
      final name = ((a as Map)['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }

    if (tag.isEmpty || apkUrl == null) return null;
    if (!_isNewer(tag, current)) return null;

    return UpdateInfo(
      version: tag,
      currentVersion: current,
      url: apkUrl,
      notes: notes,
    );
  }

  /// Compara versões "x.y.z" (ignora sufixo +build).
  static bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();
    final l = parse(latest);
    final c = parse(current);
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  /// Baixa o APK reportando progresso (0..1) e abre o instalador no Android.
  static Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'update.apk'));

    final client = http.Client();
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      final total = resp.contentLength ?? 0;
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in resp.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
    } finally {
      client.close();
    }

    if (Platform.isAndroid) {
      await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
    }
  }
}
