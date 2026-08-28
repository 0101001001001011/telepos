import 'package:freezed_annotation/freezed_annotation.dart';

part 'telegram_message.freezed.dart';
part 'telegram_message.g.dart';

enum MessageDirection { incoming, outgoing }

enum MessageContentType {
  text,
  photo,
  document,
  video,
  audio,
  sticker,
  animation,
  location,
  contact,
  systemData,
}

@freezed
abstract class TelegramMessage with _$TelegramMessage {
  const factory TelegramMessage({
    required int messageId,

    required int chatId,

    required int senderId,

    required MessageDirection direction,

    required MessageContentType contentType,

    @Default('') String text,

    required DateTime date,

    DateTime? editDate,

    int? replyToMessageId,

    @Default(false) bool isRead,

    @Default(false) bool isSystemMessage,

    Map<String, dynamic>? metadata,

    String? filePath,

    int? fileSize,

    String? mimeType,
  }) = _TelegramMessage;

  factory TelegramMessage.fromJson(Map<String, dynamic> json) =>
      _$TelegramMessageFromJson(json);
}
