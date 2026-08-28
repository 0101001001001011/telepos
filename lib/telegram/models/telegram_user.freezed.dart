// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telegram_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TelegramUser {

 int get userId; String get firstName; String get lastName; String? get username; String? get phoneNumber; bool get isBot; bool get isOnline; DateTime? get lastOnline; String? get profilePhotoPath; String? get posRole; int? get staffId; bool get isVerified; DateTime? get verifiedAt; String? get verificationType;
/// Create a copy of TelegramUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelegramUserCopyWith<TelegramUser> get copyWith => _$TelegramUserCopyWithImpl<TelegramUser>(this as TelegramUser, _$identity);

  /// Serializes this TelegramUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelegramUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.username, username) || other.username == username)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.lastOnline, lastOnline) || other.lastOnline == lastOnline)&&(identical(other.profilePhotoPath, profilePhotoPath) || other.profilePhotoPath == profilePhotoPath)&&(identical(other.posRole, posRole) || other.posRole == posRole)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.verificationType, verificationType) || other.verificationType == verificationType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,firstName,lastName,username,phoneNumber,isBot,isOnline,lastOnline,profilePhotoPath,posRole,staffId,isVerified,verifiedAt,verificationType);

@override
String toString() {
  return 'TelegramUser(userId: $userId, firstName: $firstName, lastName: $lastName, username: $username, phoneNumber: $phoneNumber, isBot: $isBot, isOnline: $isOnline, lastOnline: $lastOnline, profilePhotoPath: $profilePhotoPath, posRole: $posRole, staffId: $staffId, isVerified: $isVerified, verifiedAt: $verifiedAt, verificationType: $verificationType)';
}


}

/// @nodoc
abstract mixin class $TelegramUserCopyWith<$Res>  {
  factory $TelegramUserCopyWith(TelegramUser value, $Res Function(TelegramUser) _then) = _$TelegramUserCopyWithImpl;
@useResult
$Res call({
 int userId, String firstName, String lastName, String? username, String? phoneNumber, bool isBot, bool isOnline, DateTime? lastOnline, String? profilePhotoPath, String? posRole, int? staffId, bool isVerified, DateTime? verifiedAt, String? verificationType
});




}
/// @nodoc
class _$TelegramUserCopyWithImpl<$Res>
    implements $TelegramUserCopyWith<$Res> {
  _$TelegramUserCopyWithImpl(this._self, this._then);

  final TelegramUser _self;
  final $Res Function(TelegramUser) _then;

/// Create a copy of TelegramUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? firstName = null,Object? lastName = null,Object? username = freezed,Object? phoneNumber = freezed,Object? isBot = null,Object? isOnline = null,Object? lastOnline = freezed,Object? profilePhotoPath = freezed,Object? posRole = freezed,Object? staffId = freezed,Object? isVerified = null,Object? verifiedAt = freezed,Object? verificationType = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,isBot: null == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,lastOnline: freezed == lastOnline ? _self.lastOnline : lastOnline // ignore: cast_nullable_to_non_nullable
as DateTime?,profilePhotoPath: freezed == profilePhotoPath ? _self.profilePhotoPath : profilePhotoPath // ignore: cast_nullable_to_non_nullable
as String?,posRole: freezed == posRole ? _self.posRole : posRole // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as int?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,verificationType: freezed == verificationType ? _self.verificationType : verificationType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TelegramUser].
extension TelegramUserPatterns on TelegramUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TelegramUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TelegramUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TelegramUser value)  $default,){
final _that = this;
switch (_that) {
case _TelegramUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TelegramUser value)?  $default,){
final _that = this;
switch (_that) {
case _TelegramUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int userId,  String firstName,  String lastName,  String? username,  String? phoneNumber,  bool isBot,  bool isOnline,  DateTime? lastOnline,  String? profilePhotoPath,  String? posRole,  int? staffId,  bool isVerified,  DateTime? verifiedAt,  String? verificationType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TelegramUser() when $default != null:
return $default(_that.userId,_that.firstName,_that.lastName,_that.username,_that.phoneNumber,_that.isBot,_that.isOnline,_that.lastOnline,_that.profilePhotoPath,_that.posRole,_that.staffId,_that.isVerified,_that.verifiedAt,_that.verificationType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int userId,  String firstName,  String lastName,  String? username,  String? phoneNumber,  bool isBot,  bool isOnline,  DateTime? lastOnline,  String? profilePhotoPath,  String? posRole,  int? staffId,  bool isVerified,  DateTime? verifiedAt,  String? verificationType)  $default,) {final _that = this;
switch (_that) {
case _TelegramUser():
return $default(_that.userId,_that.firstName,_that.lastName,_that.username,_that.phoneNumber,_that.isBot,_that.isOnline,_that.lastOnline,_that.profilePhotoPath,_that.posRole,_that.staffId,_that.isVerified,_that.verifiedAt,_that.verificationType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int userId,  String firstName,  String lastName,  String? username,  String? phoneNumber,  bool isBot,  bool isOnline,  DateTime? lastOnline,  String? profilePhotoPath,  String? posRole,  int? staffId,  bool isVerified,  DateTime? verifiedAt,  String? verificationType)?  $default,) {final _that = this;
switch (_that) {
case _TelegramUser() when $default != null:
return $default(_that.userId,_that.firstName,_that.lastName,_that.username,_that.phoneNumber,_that.isBot,_that.isOnline,_that.lastOnline,_that.profilePhotoPath,_that.posRole,_that.staffId,_that.isVerified,_that.verifiedAt,_that.verificationType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TelegramUser implements TelegramUser {
  const _TelegramUser({required this.userId, required this.firstName, this.lastName = '', this.username, this.phoneNumber, this.isBot = false, this.isOnline = false, this.lastOnline, this.profilePhotoPath, this.posRole, this.staffId, this.isVerified = false, this.verifiedAt, this.verificationType});
  factory _TelegramUser.fromJson(Map<String, dynamic> json) => _$TelegramUserFromJson(json);

@override final  int userId;
@override final  String firstName;
@override@JsonKey() final  String lastName;
@override final  String? username;
@override final  String? phoneNumber;
@override@JsonKey() final  bool isBot;
@override@JsonKey() final  bool isOnline;
@override final  DateTime? lastOnline;
@override final  String? profilePhotoPath;
@override final  String? posRole;
@override final  int? staffId;
@override@JsonKey() final  bool isVerified;
@override final  DateTime? verifiedAt;
@override final  String? verificationType;

/// Create a copy of TelegramUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TelegramUserCopyWith<_TelegramUser> get copyWith => __$TelegramUserCopyWithImpl<_TelegramUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TelegramUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TelegramUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.username, username) || other.username == username)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.lastOnline, lastOnline) || other.lastOnline == lastOnline)&&(identical(other.profilePhotoPath, profilePhotoPath) || other.profilePhotoPath == profilePhotoPath)&&(identical(other.posRole, posRole) || other.posRole == posRole)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.verificationType, verificationType) || other.verificationType == verificationType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,firstName,lastName,username,phoneNumber,isBot,isOnline,lastOnline,profilePhotoPath,posRole,staffId,isVerified,verifiedAt,verificationType);

@override
String toString() {
  return 'TelegramUser(userId: $userId, firstName: $firstName, lastName: $lastName, username: $username, phoneNumber: $phoneNumber, isBot: $isBot, isOnline: $isOnline, lastOnline: $lastOnline, profilePhotoPath: $profilePhotoPath, posRole: $posRole, staffId: $staffId, isVerified: $isVerified, verifiedAt: $verifiedAt, verificationType: $verificationType)';
}


}

/// @nodoc
abstract mixin class _$TelegramUserCopyWith<$Res> implements $TelegramUserCopyWith<$Res> {
  factory _$TelegramUserCopyWith(_TelegramUser value, $Res Function(_TelegramUser) _then) = __$TelegramUserCopyWithImpl;
@override @useResult
$Res call({
 int userId, String firstName, String lastName, String? username, String? phoneNumber, bool isBot, bool isOnline, DateTime? lastOnline, String? profilePhotoPath, String? posRole, int? staffId, bool isVerified, DateTime? verifiedAt, String? verificationType
});




}
/// @nodoc
class __$TelegramUserCopyWithImpl<$Res>
    implements _$TelegramUserCopyWith<$Res> {
  __$TelegramUserCopyWithImpl(this._self, this._then);

  final _TelegramUser _self;
  final $Res Function(_TelegramUser) _then;

/// Create a copy of TelegramUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? firstName = null,Object? lastName = null,Object? username = freezed,Object? phoneNumber = freezed,Object? isBot = null,Object? isOnline = null,Object? lastOnline = freezed,Object? profilePhotoPath = freezed,Object? posRole = freezed,Object? staffId = freezed,Object? isVerified = null,Object? verifiedAt = freezed,Object? verificationType = freezed,}) {
  return _then(_TelegramUser(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,isBot: null == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,lastOnline: freezed == lastOnline ? _self.lastOnline : lastOnline // ignore: cast_nullable_to_non_nullable
as DateTime?,profilePhotoPath: freezed == profilePhotoPath ? _self.profilePhotoPath : profilePhotoPath // ignore: cast_nullable_to_non_nullable
as String?,posRole: freezed == posRole ? _self.posRole : posRole // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as int?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,verificationType: freezed == verificationType ? _self.verificationType : verificationType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
