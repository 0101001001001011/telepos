// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TelegramConfig _$TelegramConfigFromJson(Map<String, dynamic> json) =>
    _TelegramConfig(
      apiId: (json['apiId'] as num).toInt(),
      apiHash: json['apiHash'] as String,
      databaseDirectory: json['databaseDirectory'] as String,
      filesDirectory: json['filesDirectory'] as String,
      useTestDc: json['useTestDc'] as bool? ?? false,
      logVerbosityLevel: (json['logVerbosityLevel'] as num?)?.toInt() ?? 2,
      deviceModel: json['deviceModel'] as String? ?? 'TelePOS Terminal',
      systemVersion: json['systemVersion'] as String? ?? '',
      applicationVersion: json['applicationVersion'] as String? ?? '1.0.0',
      systemLanguageCode: json['systemLanguageCode'] as String? ?? 'ru',
      enableStorageEncryption: json['enableStorageEncryption'] as bool? ?? true,
      storageEncryptionKey: json['storageEncryptionKey'] as String?,
      useFileDatabase: json['useFileDatabase'] as bool? ?? true,
      useChatInfoDatabase: json['useChatInfoDatabase'] as bool? ?? true,
      useMessageDatabase: json['useMessageDatabase'] as bool? ?? true,
      posId: json['posId'] as String?,
      storeName: json['storeName'] as String?,
    );

Map<String, dynamic> _$TelegramConfigToJson(_TelegramConfig instance) =>
    <String, dynamic>{
      'apiId': instance.apiId,
      'apiHash': instance.apiHash,
      'databaseDirectory': instance.databaseDirectory,
      'filesDirectory': instance.filesDirectory,
      'useTestDc': instance.useTestDc,
      'logVerbosityLevel': instance.logVerbosityLevel,
      'deviceModel': instance.deviceModel,
      'systemVersion': instance.systemVersion,
      'applicationVersion': instance.applicationVersion,
      'systemLanguageCode': instance.systemLanguageCode,
      'enableStorageEncryption': instance.enableStorageEncryption,
      'storageEncryptionKey': instance.storageEncryptionKey,
      'useFileDatabase': instance.useFileDatabase,
      'useChatInfoDatabase': instance.useChatInfoDatabase,
      'useMessageDatabase': instance.useMessageDatabase,
      'posId': instance.posId,
      'storeName': instance.storeName,
    };
