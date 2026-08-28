// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationPayload _$NotificationPayloadFromJson(Map<String, dynamic> json) =>
    _NotificationPayload(
      notificationId: json['notificationId'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      priority:
          $enumDecodeNullable(
            _$NotificationPriorityEnumMap,
            json['priority'],
          ) ??
          NotificationPriority.normal,
      title: json['title'] as String,
      body: json['body'] as String,
      posId: json['posId'] as String,
      storeName: json['storeName'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      targetChatId: (json['targetChatId'] as num?)?.toInt(),
      extra: json['extra'] as Map<String, dynamic>?,
      isSent: json['isSent'] as bool? ?? false,
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
      telegramMessageId: (json['telegramMessageId'] as num?)?.toInt(),
      isSilent: json['isSilent'] as bool? ?? false,
      hasAttachment: json['hasAttachment'] as bool? ?? false,
      attachmentPath: json['attachmentPath'] as String?,
    );

Map<String, dynamic> _$NotificationPayloadToJson(
  _NotificationPayload instance,
) => <String, dynamic>{
  'notificationId': instance.notificationId,
  'type': _$NotificationTypeEnumMap[instance.type]!,
  'priority': _$NotificationPriorityEnumMap[instance.priority]!,
  'title': instance.title,
  'body': instance.body,
  'posId': instance.posId,
  'storeName': instance.storeName,
  'timestamp': instance.timestamp.toIso8601String(),
  'targetChatId': instance.targetChatId,
  'extra': instance.extra,
  'isSent': instance.isSent,
  'sentAt': instance.sentAt?.toIso8601String(),
  'telegramMessageId': instance.telegramMessageId,
  'isSilent': instance.isSilent,
  'hasAttachment': instance.hasAttachment,
  'attachmentPath': instance.attachmentPath,
};

const _$NotificationTypeEnumMap = {
  NotificationType.shift: 'shift',
  NotificationType.sale: 'sale',
  NotificationType.stock: 'stock',
  NotificationType.cash: 'cash',
  NotificationType.error: 'error',
  NotificationType.sync: 'sync',
  NotificationType.fiscal: 'fiscal',
  NotificationType.system: 'system',
};

const _$NotificationPriorityEnumMap = {
  NotificationPriority.low: 'low',
  NotificationPriority.normal: 'normal',
  NotificationPriority.high: 'high',
  NotificationPriority.critical: 'critical',
};
