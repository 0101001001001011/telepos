// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TelegramMessage _$TelegramMessageFromJson(Map<String, dynamic> json) =>
    _TelegramMessage(
      messageId: (json['messageId'] as num).toInt(),
      chatId: (json['chatId'] as num).toInt(),
      senderId: (json['senderId'] as num).toInt(),
      direction: $enumDecode(_$MessageDirectionEnumMap, json['direction']),
      contentType: $enumDecode(
        _$MessageContentTypeEnumMap,
        json['contentType'],
      ),
      text: json['text'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      editDate: json['editDate'] == null
          ? null
          : DateTime.parse(json['editDate'] as String),
      replyToMessageId: (json['replyToMessageId'] as num?)?.toInt(),
      isRead: json['isRead'] as bool? ?? false,
      isSystemMessage: json['isSystemMessage'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      filePath: json['filePath'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
    );

Map<String, dynamic> _$TelegramMessageToJson(_TelegramMessage instance) =>
    <String, dynamic>{
      'messageId': instance.messageId,
      'chatId': instance.chatId,
      'senderId': instance.senderId,
      'direction': _$MessageDirectionEnumMap[instance.direction]!,
      'contentType': _$MessageContentTypeEnumMap[instance.contentType]!,
      'text': instance.text,
      'date': instance.date.toIso8601String(),
      'editDate': instance.editDate?.toIso8601String(),
      'replyToMessageId': instance.replyToMessageId,
      'isRead': instance.isRead,
      'isSystemMessage': instance.isSystemMessage,
      'metadata': instance.metadata,
      'filePath': instance.filePath,
      'fileSize': instance.fileSize,
      'mimeType': instance.mimeType,
    };

const _$MessageDirectionEnumMap = {
  MessageDirection.incoming: 'incoming',
  MessageDirection.outgoing: 'outgoing',
};

const _$MessageContentTypeEnumMap = {
  MessageContentType.text: 'text',
  MessageContentType.photo: 'photo',
  MessageContentType.document: 'document',
  MessageContentType.video: 'video',
  MessageContentType.audio: 'audio',
  MessageContentType.sticker: 'sticker',
  MessageContentType.animation: 'animation',
  MessageContentType.location: 'location',
  MessageContentType.contact: 'contact',
  MessageContentType.systemData: 'systemData',
};
