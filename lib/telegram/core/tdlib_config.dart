import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:telepos/telegram/models/telegram_config.dart';

class TdLibConfigProvider {
  TdLibConfigProvider._();

  static Future<TelegramConfig> createDefault({
    required int apiId,
    required String apiHash,
    String? posId,
    String? storeName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tdlibDir = Directory('${appDir.path}/tdlib');
    if (!tdlibDir.existsSync()) {
      tdlibDir.createSync(recursive: true);
    }

    final filesDir = Directory('${appDir.path}/tdlib/files');
    if (!filesDir.existsSync()) {
      filesDir.createSync(recursive: true);
    }

    return TelegramConfig(
      apiId: apiId,
      apiHash: apiHash,
      databaseDirectory: tdlibDir.path,
      filesDirectory: filesDir.path,
      systemVersion: _getSystemVersion(),
      deviceModel: _getDeviceModel(),
      posId: posId,
      storeName: storeName,
    );
  }

  static String _getDeviceModel() {
    if (Platform.isWindows) return 'TelePOS Windows Terminal';
    if (Platform.isLinux) return 'TelePOS Linux Terminal';
    if (Platform.isMacOS) return 'TelePOS macOS Terminal';
    if (Platform.isAndroid) return 'TelePOS Android';
    if (Platform.isIOS) return 'TelePOS iOS';
    return 'TelePOS Terminal';
  }

  static String _getSystemVersion() {
    return Platform.operatingSystemVersion;
  }

  static List<String> validate(TelegramConfig config) {
    final errors = <String>[];

    if (config.apiId <= 0) {
      errors.add('apiId must be positive');
    }
    if (config.apiHash.isEmpty) {
      errors.add('apiHash must not be empty');
    }
    if (config.databaseDirectory.isEmpty) {
      errors.add('databaseDirectory must not be empty');
    }
    if (config.filesDirectory.isEmpty) {
      errors.add('filesDirectory must not be empty');
    }

    return errors;
  }
}
