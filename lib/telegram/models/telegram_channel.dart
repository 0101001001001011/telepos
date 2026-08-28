import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:telepos/telegram/channels/channel_types.dart';

part 'telegram_channel.freezed.dart';
part 'telegram_channel.g.dart';

@freezed
abstract class TelegramChannel with _$TelegramChannel {
  const factory TelegramChannel({
    required int chatId,

    required String title,

    required SystemChannelType channelType,

    @Default('') String description,

    String? username,

    String? inviteLink,

    @Default(true) bool isChannel,

    @Default(true) bool isPrivate,

    @Default(0) int memberCount,

    DateTime? createdAt,

    String? posId,

    String? storeName,

    @Default(true) bool isActive,
  }) = _TelegramChannel;

  factory TelegramChannel.fromJson(Map<String, dynamic> json) =>
      _$TelegramChannelFromJson(json);
}
