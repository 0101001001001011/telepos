// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationPayload {

 String get notificationId; NotificationType get type; NotificationPriority get priority; String get title; String get body; String get posId; String? get storeName; DateTime get timestamp; int? get targetChatId; Map<String, dynamic>? get extra; bool get isSent; DateTime? get sentAt; int? get telegramMessageId; bool get isSilent; bool get hasAttachment; String? get attachmentPath;
/// Create a copy of NotificationPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPayloadCopyWith<NotificationPayload> get copyWith => _$NotificationPayloadCopyWithImpl<NotificationPayload>(this as NotificationPayload, _$identity);

  /// Serializes this NotificationPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPayload&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.type, type) || other.type == type)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.posId, posId) || other.posId == posId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.targetChatId, targetChatId) || other.targetChatId == targetChatId)&&const DeepCollectionEquality().equals(other.extra, extra)&&(identical(other.isSent, isSent) || other.isSent == isSent)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.telegramMessageId, telegramMessageId) || other.telegramMessageId == telegramMessageId)&&(identical(other.isSilent, isSilent) || other.isSilent == isSilent)&&(identical(other.hasAttachment, hasAttachment) || other.hasAttachment == hasAttachment)&&(identical(other.attachmentPath, attachmentPath) || other.attachmentPath == attachmentPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,type,priority,title,body,posId,storeName,timestamp,targetChatId,const DeepCollectionEquality().hash(extra),isSent,sentAt,telegramMessageId,isSilent,hasAttachment,attachmentPath);

@override
String toString() {
  return 'NotificationPayload(notificationId: $notificationId, type: $type, priority: $priority, title: $title, body: $body, posId: $posId, storeName: $storeName, timestamp: $timestamp, targetChatId: $targetChatId, extra: $extra, isSent: $isSent, sentAt: $sentAt, telegramMessageId: $telegramMessageId, isSilent: $isSilent, hasAttachment: $hasAttachment, attachmentPath: $attachmentPath)';
}


}

/// @nodoc
abstract mixin class $NotificationPayloadCopyWith<$Res>  {
  factory $NotificationPayloadCopyWith(NotificationPayload value, $Res Function(NotificationPayload) _then) = _$NotificationPayloadCopyWithImpl;
@useResult
$Res call({
 String notificationId, NotificationType type, NotificationPriority priority, String title, String body, String posId, String? storeName, DateTime timestamp, int? targetChatId, Map<String, dynamic>? extra, bool isSent, DateTime? sentAt, int? telegramMessageId, bool isSilent, bool hasAttachment, String? attachmentPath
});




}
/// @nodoc
class _$NotificationPayloadCopyWithImpl<$Res>
    implements $NotificationPayloadCopyWith<$Res> {
  _$NotificationPayloadCopyWithImpl(this._self, this._then);

  final NotificationPayload _self;
  final $Res Function(NotificationPayload) _then;

/// Create a copy of NotificationPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notificationId = null,Object? type = null,Object? priority = null,Object? title = null,Object? body = null,Object? posId = null,Object? storeName = freezed,Object? timestamp = null,Object? targetChatId = freezed,Object? extra = freezed,Object? isSent = null,Object? sentAt = freezed,Object? telegramMessageId = freezed,Object? isSilent = null,Object? hasAttachment = null,Object? attachmentPath = freezed,}) {
  return _then(_self.copyWith(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as NotificationPriority,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,posId: null == posId ? _self.posId : posId // ignore: cast_nullable_to_non_nullable
as String,storeName: freezed == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,targetChatId: freezed == targetChatId ? _self.targetChatId : targetChatId // ignore: cast_nullable_to_non_nullable
as int?,extra: freezed == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isSent: null == isSent ? _self.isSent : isSent // ignore: cast_nullable_to_non_nullable
as bool,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,telegramMessageId: freezed == telegramMessageId ? _self.telegramMessageId : telegramMessageId // ignore: cast_nullable_to_non_nullable
as int?,isSilent: null == isSilent ? _self.isSilent : isSilent // ignore: cast_nullable_to_non_nullable
as bool,hasAttachment: null == hasAttachment ? _self.hasAttachment : hasAttachment // ignore: cast_nullable_to_non_nullable
as bool,attachmentPath: freezed == attachmentPath ? _self.attachmentPath : attachmentPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationPayload].
extension NotificationPayloadPatterns on NotificationPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPayload value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPayload value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String notificationId,  NotificationType type,  NotificationPriority priority,  String title,  String body,  String posId,  String? storeName,  DateTime timestamp,  int? targetChatId,  Map<String, dynamic>? extra,  bool isSent,  DateTime? sentAt,  int? telegramMessageId,  bool isSilent,  bool hasAttachment,  String? attachmentPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPayload() when $default != null:
return $default(_that.notificationId,_that.type,_that.priority,_that.title,_that.body,_that.posId,_that.storeName,_that.timestamp,_that.targetChatId,_that.extra,_that.isSent,_that.sentAt,_that.telegramMessageId,_that.isSilent,_that.hasAttachment,_that.attachmentPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String notificationId,  NotificationType type,  NotificationPriority priority,  String title,  String body,  String posId,  String? storeName,  DateTime timestamp,  int? targetChatId,  Map<String, dynamic>? extra,  bool isSent,  DateTime? sentAt,  int? telegramMessageId,  bool isSilent,  bool hasAttachment,  String? attachmentPath)  $default,) {final _that = this;
switch (_that) {
case _NotificationPayload():
return $default(_that.notificationId,_that.type,_that.priority,_that.title,_that.body,_that.posId,_that.storeName,_that.timestamp,_that.targetChatId,_that.extra,_that.isSent,_that.sentAt,_that.telegramMessageId,_that.isSilent,_that.hasAttachment,_that.attachmentPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String notificationId,  NotificationType type,  NotificationPriority priority,  String title,  String body,  String posId,  String? storeName,  DateTime timestamp,  int? targetChatId,  Map<String, dynamic>? extra,  bool isSent,  DateTime? sentAt,  int? telegramMessageId,  bool isSilent,  bool hasAttachment,  String? attachmentPath)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPayload() when $default != null:
return $default(_that.notificationId,_that.type,_that.priority,_that.title,_that.body,_that.posId,_that.storeName,_that.timestamp,_that.targetChatId,_that.extra,_that.isSent,_that.sentAt,_that.telegramMessageId,_that.isSilent,_that.hasAttachment,_that.attachmentPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationPayload implements NotificationPayload {
  const _NotificationPayload({required this.notificationId, required this.type, this.priority = NotificationPriority.normal, required this.title, required this.body, required this.posId, this.storeName, required this.timestamp, this.targetChatId, final  Map<String, dynamic>? extra, this.isSent = false, this.sentAt, this.telegramMessageId, this.isSilent = false, this.hasAttachment = false, this.attachmentPath}): _extra = extra;
  factory _NotificationPayload.fromJson(Map<String, dynamic> json) => _$NotificationPayloadFromJson(json);

@override final  String notificationId;
@override final  NotificationType type;
@override@JsonKey() final  NotificationPriority priority;
@override final  String title;
@override final  String body;
@override final  String posId;
@override final  String? storeName;
@override final  DateTime timestamp;
@override final  int? targetChatId;
 final  Map<String, dynamic>? _extra;
@override Map<String, dynamic>? get extra {
  final value = _extra;
  if (value == null) return null;
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool isSent;
@override final  DateTime? sentAt;
@override final  int? telegramMessageId;
@override@JsonKey() final  bool isSilent;
@override@JsonKey() final  bool hasAttachment;
@override final  String? attachmentPath;

/// Create a copy of NotificationPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPayloadCopyWith<_NotificationPayload> get copyWith => __$NotificationPayloadCopyWithImpl<_NotificationPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPayload&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.type, type) || other.type == type)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.posId, posId) || other.posId == posId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.targetChatId, targetChatId) || other.targetChatId == targetChatId)&&const DeepCollectionEquality().equals(other._extra, _extra)&&(identical(other.isSent, isSent) || other.isSent == isSent)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.telegramMessageId, telegramMessageId) || other.telegramMessageId == telegramMessageId)&&(identical(other.isSilent, isSilent) || other.isSilent == isSilent)&&(identical(other.hasAttachment, hasAttachment) || other.hasAttachment == hasAttachment)&&(identical(other.attachmentPath, attachmentPath) || other.attachmentPath == attachmentPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,type,priority,title,body,posId,storeName,timestamp,targetChatId,const DeepCollectionEquality().hash(_extra),isSent,sentAt,telegramMessageId,isSilent,hasAttachment,attachmentPath);

@override
String toString() {
  return 'NotificationPayload(notificationId: $notificationId, type: $type, priority: $priority, title: $title, body: $body, posId: $posId, storeName: $storeName, timestamp: $timestamp, targetChatId: $targetChatId, extra: $extra, isSent: $isSent, sentAt: $sentAt, telegramMessageId: $telegramMessageId, isSilent: $isSilent, hasAttachment: $hasAttachment, attachmentPath: $attachmentPath)';
}


}

/// @nodoc
abstract mixin class _$NotificationPayloadCopyWith<$Res> implements $NotificationPayloadCopyWith<$Res> {
  factory _$NotificationPayloadCopyWith(_NotificationPayload value, $Res Function(_NotificationPayload) _then) = __$NotificationPayloadCopyWithImpl;
@override @useResult
$Res call({
 String notificationId, NotificationType type, NotificationPriority priority, String title, String body, String posId, String? storeName, DateTime timestamp, int? targetChatId, Map<String, dynamic>? extra, bool isSent, DateTime? sentAt, int? telegramMessageId, bool isSilent, bool hasAttachment, String? attachmentPath
});




}
/// @nodoc
class __$NotificationPayloadCopyWithImpl<$Res>
    implements _$NotificationPayloadCopyWith<$Res> {
  __$NotificationPayloadCopyWithImpl(this._self, this._then);

  final _NotificationPayload _self;
  final $Res Function(_NotificationPayload) _then;

/// Create a copy of NotificationPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notificationId = null,Object? type = null,Object? priority = null,Object? title = null,Object? body = null,Object? posId = null,Object? storeName = freezed,Object? timestamp = null,Object? targetChatId = freezed,Object? extra = freezed,Object? isSent = null,Object? sentAt = freezed,Object? telegramMessageId = freezed,Object? isSilent = null,Object? hasAttachment = null,Object? attachmentPath = freezed,}) {
  return _then(_NotificationPayload(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as NotificationPriority,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,posId: null == posId ? _self.posId : posId // ignore: cast_nullable_to_non_nullable
as String,storeName: freezed == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,targetChatId: freezed == targetChatId ? _self.targetChatId : targetChatId // ignore: cast_nullable_to_non_nullable
as int?,extra: freezed == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isSent: null == isSent ? _self.isSent : isSent // ignore: cast_nullable_to_non_nullable
as bool,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,telegramMessageId: freezed == telegramMessageId ? _self.telegramMessageId : telegramMessageId // ignore: cast_nullable_to_non_nullable
as int?,isSilent: null == isSilent ? _self.isSilent : isSilent // ignore: cast_nullable_to_non_nullable
as bool,hasAttachment: null == hasAttachment ? _self.hasAttachment : hasAttachment // ignore: cast_nullable_to_non_nullable
as bool,attachmentPath: freezed == attachmentPath ? _self.attachmentPath : attachmentPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
