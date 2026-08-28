import 'package:freezed_annotation/freezed_annotation.dart';

part 'telegram_user.freezed.dart';
part 'telegram_user.g.dart';

@freezed
abstract class TelegramUser with _$TelegramUser {
  const factory TelegramUser({
    required int userId,

    required String firstName,

    @Default('') String lastName,

    String? username,

    String? phoneNumber,

    @Default(false) bool isBot,

    @Default(false) bool isOnline,

    DateTime? lastOnline,

    String? profilePhotoPath,

    String? posRole,

    int? staffId,

    @Default(false) bool isVerified,

    DateTime? verifiedAt,

    String? verificationType,
  }) = _TelegramUser;

  factory TelegramUser.fromJson(Map<String, dynamic> json) =>
      _$TelegramUserFromJson(json);
}
