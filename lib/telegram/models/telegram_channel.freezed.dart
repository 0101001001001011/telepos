// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telegram_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TelegramChannel {

 int get chatId; String get title; SystemChannelType get channelType; String get description; String? get username; String? get inviteLink; bool get isChannel; bool get isPrivate; int get memberCount; DateTime? get createdAt; String? get posId; String? get storeName; bool get isActive;
/// Create a copy of TelegramChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelegramChannelCopyWith<TelegramChannel> get copyWith => _$TelegramChannelCopyWithImpl<TelegramChannel>(this as TelegramChannel, _$identity);

  /// Serializes this TelegramChannel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelegramChannel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.channelType, channelType) || other.channelType == channelType)&&(identical(other.description, description) || other.description == description)&&(identical(other.username, username) || other.username == username)&&(identical(other.inviteLink, inviteLink) || other.inviteLink == inviteLink)&&(identical(other.isChannel, isChannel) || other.isChannel == isChannel)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.posId, posId) || other.posId == posId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,title,channelType,description,username,inviteLink,isChannel,isPrivate,memberCount,createdAt,posId,storeName,isActive);

@override
String toString() {
  return 'TelegramChannel(chatId: $chatId, title: $title, channelType: $channelType, description: $description, username: $username, inviteLink: $inviteLink, isChannel: $isChannel, isPrivate: $isPrivate, memberCount: $memberCount, createdAt: $createdAt, posId: $posId, storeName: $storeName, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $TelegramChannelCopyWith<$Res>  {
  factory $TelegramChannelCopyWith(TelegramChannel value, $Res Function(TelegramChannel) _then) = _$TelegramChannelCopyWithImpl;
@useResult
$Res call({
 int chatId, String title, SystemChannelType channelType, String description, String? username, String? inviteLink, bool isChannel, bool isPrivate, int memberCount, DateTime? createdAt, String? posId, String? storeName, bool isActive
});




}
/// @nodoc
class _$TelegramChannelCopyWithImpl<$Res>
    implements $TelegramChannelCopyWith<$Res> {
  _$TelegramChannelCopyWithImpl(this._self, this._then);

  final TelegramChannel _self;
  final $Res Function(TelegramChannel) _then;

/// Create a copy of TelegramChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? title = null,Object? channelType = null,Object? description = null,Object? username = freezed,Object? inviteLink = freezed,Object? isChannel = null,Object? isPrivate = null,Object? memberCount = null,Object? createdAt = freezed,Object? posId = freezed,Object? storeName = freezed,Object? isActive = null,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,channelType: null == channelType ? _self.channelType : channelType // ignore: cast_nullable_to_non_nullable
as SystemChannelType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,inviteLink: freezed == inviteLink ? _self.inviteLink : inviteLink // ignore: cast_nullable_to_non_nullable
as String?,isChannel: null == isChannel ? _self.isChannel : isChannel // ignore: cast_nullable_to_non_nullable
as bool,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,posId: freezed == posId ? _self.posId : posId // ignore: cast_nullable_to_non_nullable
as String?,storeName: freezed == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TelegramChannel].
extension TelegramChannelPatterns on TelegramChannel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TelegramChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TelegramChannel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TelegramChannel value)  $default,){
final _that = this;
switch (_that) {
case _TelegramChannel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TelegramChannel value)?  $default,){
final _that = this;
switch (_that) {
case _TelegramChannel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int chatId,  String title,  SystemChannelType channelType,  String description,  String? username,  String? inviteLink,  bool isChannel,  bool isPrivate,  int memberCount,  DateTime? createdAt,  String? posId,  String? storeName,  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TelegramChannel() when $default != null:
return $default(_that.chatId,_that.title,_that.channelType,_that.description,_that.username,_that.inviteLink,_that.isChannel,_that.isPrivate,_that.memberCount,_that.createdAt,_that.posId,_that.storeName,_that.isActive);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int chatId,  String title,  SystemChannelType channelType,  String description,  String? username,  String? inviteLink,  bool isChannel,  bool isPrivate,  int memberCount,  DateTime? createdAt,  String? posId,  String? storeName,  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _TelegramChannel():
return $default(_that.chatId,_that.title,_that.channelType,_that.description,_that.username,_that.inviteLink,_that.isChannel,_that.isPrivate,_that.memberCount,_that.createdAt,_that.posId,_that.storeName,_that.isActive);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int chatId,  String title,  SystemChannelType channelType,  String description,  String? username,  String? inviteLink,  bool isChannel,  bool isPrivate,  int memberCount,  DateTime? createdAt,  String? posId,  String? storeName,  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _TelegramChannel() when $default != null:
return $default(_that.chatId,_that.title,_that.channelType,_that.description,_that.username,_that.inviteLink,_that.isChannel,_that.isPrivate,_that.memberCount,_that.createdAt,_that.posId,_that.storeName,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TelegramChannel implements TelegramChannel {
  const _TelegramChannel({required this.chatId, required this.title, required this.channelType, this.description = '', this.username, this.inviteLink, this.isChannel = true, this.isPrivate = true, this.memberCount = 0, this.createdAt, this.posId, this.storeName, this.isActive = true});
  factory _TelegramChannel.fromJson(Map<String, dynamic> json) => _$TelegramChannelFromJson(json);

@override final  int chatId;
@override final  String title;
@override final  SystemChannelType channelType;
@override@JsonKey() final  String description;
@override final  String? username;
@override final  String? inviteLink;
@override@JsonKey() final  bool isChannel;
@override@JsonKey() final  bool isPrivate;
@override@JsonKey() final  int memberCount;
@override final  DateTime? createdAt;
@override final  String? posId;
@override final  String? storeName;
@override@JsonKey() final  bool isActive;

/// Create a copy of TelegramChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TelegramChannelCopyWith<_TelegramChannel> get copyWith => __$TelegramChannelCopyWithImpl<_TelegramChannel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TelegramChannelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TelegramChannel&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.title, title) || other.title == title)&&(identical(other.channelType, channelType) || other.channelType == channelType)&&(identical(other.description, description) || other.description == description)&&(identical(other.username, username) || other.username == username)&&(identical(other.inviteLink, inviteLink) || other.inviteLink == inviteLink)&&(identical(other.isChannel, isChannel) || other.isChannel == isChannel)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.posId, posId) || other.posId == posId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chatId,title,channelType,description,username,inviteLink,isChannel,isPrivate,memberCount,createdAt,posId,storeName,isActive);

@override
String toString() {
  return 'TelegramChannel(chatId: $chatId, title: $title, channelType: $channelType, description: $description, username: $username, inviteLink: $inviteLink, isChannel: $isChannel, isPrivate: $isPrivate, memberCount: $memberCount, createdAt: $createdAt, posId: $posId, storeName: $storeName, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$TelegramChannelCopyWith<$Res> implements $TelegramChannelCopyWith<$Res> {
  factory _$TelegramChannelCopyWith(_TelegramChannel value, $Res Function(_TelegramChannel) _then) = __$TelegramChannelCopyWithImpl;
@override @useResult
$Res call({
 int chatId, String title, SystemChannelType channelType, String description, String? username, String? inviteLink, bool isChannel, bool isPrivate, int memberCount, DateTime? createdAt, String? posId, String? storeName, bool isActive
});




}
/// @nodoc
class __$TelegramChannelCopyWithImpl<$Res>
    implements _$TelegramChannelCopyWith<$Res> {
  __$TelegramChannelCopyWithImpl(this._self, this._then);

  final _TelegramChannel _self;
  final $Res Function(_TelegramChannel) _then;

/// Create a copy of TelegramChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? title = null,Object? channelType = null,Object? description = null,Object? username = freezed,Object? inviteLink = freezed,Object? isChannel = null,Object? isPrivate = null,Object? memberCount = null,Object? createdAt = freezed,Object? posId = freezed,Object? storeName = freezed,Object? isActive = null,}) {
  return _then(_TelegramChannel(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,channelType: null == channelType ? _self.channelType : channelType // ignore: cast_nullable_to_non_nullable
as SystemChannelType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,inviteLink: freezed == inviteLink ? _self.inviteLink : inviteLink // ignore: cast_nullable_to_non_nullable
as String?,isChannel: null == isChannel ? _self.isChannel : isChannel // ignore: cast_nullable_to_non_nullable
as bool,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,posId: freezed == posId ? _self.posId : posId // ignore: cast_nullable_to_non_nullable
as String?,storeName: freezed == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
