import 'package:telepos/app/config/app_version.dart';

enum BuildMode { dev, test, prod }

enum HttpLoggingLevel { none, basic, headers, body }

class BuildConfig {
  const BuildConfig({
    this.version = kAppVersion,
    this.mode = BuildMode.dev,
    this.host = 'prod',
    this.restApiVersion = '1.0',
    this.httpLoggingLevel = HttpLoggingLevel.none,
  });

  factory BuildConfig.fromEnvironment() {
    const modeStr = String.fromEnvironment('BUILD_MODE', defaultValue: 'dev');
    const host = String.fromEnvironment('HOST', defaultValue: 'prod');
    const restApiVer = String.fromEnvironment(
      'REST_API_VER',
      defaultValue: '1.0',
    );
    const loggingStr = String.fromEnvironment(
      'HTTP_LOGGING',
      defaultValue: 'none',
    );

    return BuildConfig(
      // Умолчание — настоящая версия продукта, а не выдуманная `1.0.0`:
      // сборка без `--dart-define=VERSION` показывала зрителю чужое число.
      version: const String.fromEnvironment(
        'VERSION',
        defaultValue: kAppVersion,
      ),
      mode: _parseMode(modeStr),
      host: host,
      restApiVersion: restApiVer,
      httpLoggingLevel: _parseLoggingLevel(loggingStr),
    );
  }

  final String version;

  final BuildMode mode;

  final String host;

  final String restApiVersion;

  final HttpLoggingLevel httpLoggingLevel;

  bool get isProduction => mode == BuildMode.prod;

  bool get isDev => mode == BuildMode.dev;

  bool get isTest => mode == BuildMode.test;

  static BuildMode _parseMode(String value) {
    switch (value.toLowerCase()) {
      case 'prod':
        return BuildMode.prod;
      case 'test':
        return BuildMode.test;
      default:
        return BuildMode.dev;
    }
  }

  static HttpLoggingLevel _parseLoggingLevel(String value) {
    switch (value.toLowerCase()) {
      case 'basic':
        return HttpLoggingLevel.basic;
      case 'headers':
        return HttpLoggingLevel.headers;
      case 'body':
        return HttpLoggingLevel.body;
      default:
        return HttpLoggingLevel.none;
    }
  }
}
