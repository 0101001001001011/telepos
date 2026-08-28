// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TelegramChannel _$TelegramChannelFromJson(Map<String, dynamic> json) =>
    _TelegramChannel(
      chatId: (json['chatId'] as num).toInt(),
      title: json['title'] as String,
      channelType: $enumDecode(_$SystemChannelTypeEnumMap, json['channelType']),
      description: json['description'] as String? ?? '',
      username: json['username'] as String?,
      inviteLink: json['inviteLink'] as String?,
      isChannel: json['isChannel'] as bool? ?? true,
      isPrivate: json['isPrivate'] as bool? ?? true,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      posId: json['posId'] as String?,
      storeName: json['storeName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$TelegramChannelToJson(_TelegramChannel instance) =>
    <String, dynamic>{
      'chatId': instance.chatId,
      'title': instance.title,
      'channelType': _$SystemChannelTypeEnumMap[instance.channelType]!,
      'description': instance.description,
      'username': instance.username,
      'inviteLink': instance.inviteLink,
      'isChannel': instance.isChannel,
      'isPrivate': instance.isPrivate,
      'memberCount': instance.memberCount,
      'createdAt': instance.createdAt?.toIso8601String(),
      'posId': instance.posId,
      'storeName': instance.storeName,
      'isActive': instance.isActive,
    };

const _$SystemChannelTypeEnumMap = {
  SystemChannelType.posSystem: 'posSystem',
  SystemChannelType.posSales: 'posSales',
  SystemChannelType.posAlerts: 'posAlerts',
  SystemChannelType.posReports: 'posReports',
  SystemChannelType.posSync: 'posSync',
  SystemChannelType.posFiscal: 'posFiscal',
  SystemChannelType.staffChat: 'staffChat',
  SystemChannelType.posDataExchange: 'posDataExchange',
  SystemChannelType.posTerminalStatus: 'posTerminalStatus',
  SystemChannelType.posBackup: 'posBackup',
};
