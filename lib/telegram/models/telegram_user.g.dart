// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TelegramUser _$TelegramUserFromJson(Map<String, dynamic> json) =>
    _TelegramUser(
      userId: (json['userId'] as num).toInt(),
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isBot: json['isBot'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      lastOnline: json['lastOnline'] == null
          ? null
          : DateTime.parse(json['lastOnline'] as String),
      profilePhotoPath: json['profilePhotoPath'] as String?,
      posRole: json['posRole'] as String?,
      staffId: (json['staffId'] as num?)?.toInt(),
      isVerified: json['isVerified'] as bool? ?? false,
      verifiedAt: json['verifiedAt'] == null
          ? null
          : DateTime.parse(json['verifiedAt'] as String),
      verificationType: json['verificationType'] as String?,
    );

Map<String, dynamic> _$TelegramUserToJson(_TelegramUser instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'username': instance.username,
      'phoneNumber': instance.phoneNumber,
      'isBot': instance.isBot,
      'isOnline': instance.isOnline,
      'lastOnline': instance.lastOnline?.toIso8601String(),
      'profilePhotoPath': instance.profilePhotoPath,
      'posRole': instance.posRole,
      'staffId': instance.staffId,
      'isVerified': instance.isVerified,
      'verifiedAt': instance.verifiedAt?.toIso8601String(),
      'verificationType': instance.verificationType,
    };
