import 'package:freezed_annotation/freezed_annotation.dart';

part 'telegram_config.freezed.dart';
part 'telegram_config.g.dart';

@freezed
abstract class TelegramConfig with _$TelegramConfig {
  const factory TelegramConfig({
    required int apiId,

    required String apiHash,

    required String databaseDirectory,

    required String filesDirectory,

    @Default(false) bool useTestDc,

    @Default(2) int logVerbosityLevel,

    @Default('TelePOS Terminal') String deviceModel,

    @Default('') String systemVersion,

    @Default('1.0.0') String applicationVersion,

    @Default('ru') String systemLanguageCode,

    @Default(true) bool enableStorageEncryption,

    String? storageEncryptionKey,

    @Default(true) bool useFileDatabase,

    @Default(true) bool useChatInfoDatabase,

    @Default(true) bool useMessageDatabase,

    String? posId,

    String? storeName,
  }) = _TelegramConfig;

  factory TelegramConfig.fromJson(Map<String, dynamic> json) =>
      _$TelegramConfigFromJson(json);
}
