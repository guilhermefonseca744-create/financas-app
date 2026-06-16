/// Configuração do app, incluindo o repositório usado para atualizações.
class AppConfig {
  /// Usuário/organização do GitHub onde ficam as releases.
  static const String githubOwner = 'guilhermefonseca744-create';

  /// Nome do repositório onde você publica as releases (com o APK anexado).
  static const String githubRepo = 'financas-app';

  /// O updater só funciona depois que o owner for preenchido.
  static bool get updatesConfigured =>
      githubOwner.isNotEmpty && githubOwner != 'SEU_USUARIO';

  static Uri get latestReleaseApi => Uri.parse(
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest');

  static Uri get releasesPage =>
      Uri.parse('https://github.com/$githubOwner/$githubRepo/releases');
}
