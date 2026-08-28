import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_payload.freezed.dart';
part 'notification_payload.g.dart';

enum NotificationType { shift, sale, stock, cash, error, sync, fiscal, system }

enum NotificationPriority { low, normal, high, critical }

@freezed
abstract class NotificationPayload with _$NotificationPayload {
  const factory NotificationPayload({
    required String notificationId,

    required NotificationType type,

    @Default(NotificationPriority.normal) NotificationPriority priority,

    required String title,

    required String body,

    required String posId,

    String? storeName,

    required DateTime timestamp,

    int? targetChatId,

    Map<String, dynamic>? extra,

    @Default(false) bool isSent,

    DateTime? sentAt,

    int? telegramMessageId,

    @Default(false) bool isSilent,

    @Default(false) bool hasAttachment,

    String? attachmentPath,
  }) = _NotificationPayload;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}
