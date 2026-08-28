// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telegram_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TelegramMessage {

 int get messageId; int get chatId; int get senderId; MessageDirection get direction; MessageContentType get contentType; String get text; DateTime get date; DateTime? get editDate; int? get replyToMessageId; bool get isRead; bool get isSystemMessage; Map<String, dynamic>? get metadata; String? get filePath; int? get fileSize; String? get mimeType;
/// Create a copy of TelegramMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelegramMessageCopyWith<TelegramMessage> get copyWith => _$TelegramMessageCopyWithImpl<TelegramMessage>(this as TelegramMessage, _$identity);

  /// Serializes this TelegramMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelegramMessage&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.text, text) || other.text == text)&&(identical(other.date, date) || other.date == date)&&(identical(other.editDate, editDate) || other.editDate == editDate)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.isSystemMessage, isSystemMessage) || other.isSystemMessage == isSystemMessage)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageId,chatId,senderId,direction,contentType,text,date,editDate,replyToMessageId,isRead,isSystemMessage,const DeepCollectionEquality().hash(metadata),filePath,fileSize,mimeType);

@override
String toString() {
  return 'TelegramMessage(messageId: $messageId, chatId: $chatId, senderId: $senderId, direction: $direction, contentType: $contentType, text: $text, date: $date, editDate: $editDate, replyToMessageId: $replyToMessageId, isRead: $isRead, isSystemMessage: $isSystemMessage, metadata: $metadata, filePath: $filePath, fileSize: $fileSize, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class $TelegramMessageCopyWith<$Res>  {
  factory $TelegramMessageCopyWith(TelegramMessage value, $Res Function(TelegramMessage) _then) = _$TelegramMessageCopyWithImpl;
@useResult
$Res call({
 int messageId, int chatId, int senderId, MessageDirection direction, MessageContentType contentType, String text, DateTime date, DateTime? editDate, int? replyToMessageId, bool isRead, bool isSystemMessage, Map<String, dynamic>? metadata, String? filePath, int? fileSize, String? mimeType
});




}
/// @nodoc
class _$TelegramMessageCopyWithImpl<$Res>
    implements $TelegramMessageCopyWith<$Res> {
  _$TelegramMessageCopyWithImpl(this._self, this._then);

  final TelegramMessage _self;
  final $Res Function(TelegramMessage) _then;

/// Create a copy of TelegramMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? chatId = null,Object? senderId = null,Object? direction = null,Object? contentType = null,Object? text = null,Object? date = null,Object? editDate = freezed,Object? replyToMessageId = freezed,Object? isRead = null,Object? isSystemMessage = null,Object? metadata = freezed,Object? filePath = freezed,Object? fileSize = freezed,Object? mimeType = freezed,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as int,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as MessageDirection,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as MessageContentType,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,editDate: freezed == editDate ? _self.editDate : editDate // ignore: cast_nullable_to_non_nullable
as DateTime?,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as int?,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,isSystemMessage: null == isSystemMessage ? _self.isSystemMessage : isSystemMessage // ignore: cast_nullable_to_non_nullable
as bool,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,filePath: freezed == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String?,fileSize: freezed == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TelegramMessage].
extension TelegramMessagePatterns on TelegramMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TelegramMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TelegramMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TelegramMessage value)  $default,){
final _that = this;
switch (_that) {
case _TelegramMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TelegramMessage value)?  $default,){
final _that = this;
switch (_that) {
case _TelegramMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int messageId,  int chatId,  int senderId,  MessageDirection direction,  MessageContentType contentType,  String text,  DateTime date,  DateTime? editDate,  int? replyToMessageId,  bool isRead,  bool isSystemMessage,  Map<String, dynamic>? metadata,  String? filePath,  int? fileSize,  String? mimeType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TelegramMessage() when $default != null:
return $default(_that.messageId,_that.chatId,_that.senderId,_that.direction,_that.contentType,_that.text,_that.date,_that.editDate,_that.replyToMessageId,_that.isRead,_that.isSystemMessage,_that.metadata,_that.filePath,_that.fileSize,_that.mimeType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int messageId,  int chatId,  int senderId,  MessageDirection direction,  MessageContentType contentType,  String text,  DateTime date,  DateTime? editDate,  int? replyToMessageId,  bool isRead,  bool isSystemMessage,  Map<String, dynamic>? metadata,  String? filePath,  int? fileSize,  String? mimeType)  $default,) {final _that = this;
switch (_that) {
case _TelegramMessage():
return $default(_that.messageId,_that.chatId,_that.senderId,_that.direction,_that.contentType,_that.text,_that.date,_that.editDate,_that.replyToMessageId,_that.isRead,_that.isSystemMessage,_that.metadata,_that.filePath,_that.fileSize,_that.mimeType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int messageId,  int chatId,  int senderId,  MessageDirection direction,  MessageContentType contentType,  String text,  DateTime date,  DateTime? editDate,  int? replyToMessageId,  bool isRead,  bool isSystemMessage,  Map<String, dynamic>? metadata,  String? filePath,  int? fileSize,  String? mimeType)?  $default,) {final _that = this;
switch (_that) {
case _TelegramMessage() when $default != null:
return $default(_that.messageId,_that.chatId,_that.senderId,_that.direction,_that.contentType,_that.text,_that.date,_that.editDate,_that.replyToMessageId,_that.isRead,_that.isSystemMessage,_that.metadata,_that.filePath,_that.fileSize,_that.mimeType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TelegramMessage implements TelegramMessage {
  const _TelegramMessage({required this.messageId, required this.chatId, required this.senderId, required this.direction, required this.contentType, this.text = '', required this.date, this.editDate, this.replyToMessageId, this.isRead = false, this.isSystemMessage = false, final  Map<String, dynamic>? metadata, this.filePath, this.fileSize, this.mimeType}): _metadata = metadata;
  factory _TelegramMessage.fromJson(Map<String, dynamic> json) => _$TelegramMessageFromJson(json);

@override final  int messageId;
@override final  int chatId;
@override final  int senderId;
@override final  MessageDirection direction;
@override final  MessageContentType contentType;
@override@JsonKey() final  String text;
@override final  DateTime date;
@override final  DateTime? editDate;
@override final  int? replyToMessageId;
@override@JsonKey() final  bool isRead;
@override@JsonKey() final  bool isSystemMessage;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? filePath;
@override final  int? fileSize;
@override final  String? mimeType;

/// Create a copy of TelegramMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TelegramMessageCopyWith<_TelegramMessage> get copyWith => __$TelegramMessageCopyWithImpl<_TelegramMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TelegramMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TelegramMessage&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.text, text) || other.text == text)&&(identical(other.date, date) || other.date == date)&&(identical(other.editDate, editDate) || other.editDate == editDate)&&(identical(other.replyToMessageId, replyToMessageId) || other.replyToMessageId == replyToMessageId)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.isSystemMessage, isSystemMessage) || other.isSystemMessage == isSystemMessage)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageId,chatId,senderId,direction,contentType,text,date,editDate,replyToMessageId,isRead,isSystemMessage,const DeepCollectionEquality().hash(_metadata),filePath,fileSize,mimeType);

@override
String toString() {
  return 'TelegramMessage(messageId: $messageId, chatId: $chatId, senderId: $senderId, direction: $direction, contentType: $contentType, text: $text, date: $date, editDate: $editDate, replyToMessageId: $replyToMessageId, isRead: $isRead, isSystemMessage: $isSystemMessage, metadata: $metadata, filePath: $filePath, fileSize: $fileSize, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class _$TelegramMessageCopyWith<$Res> implements $TelegramMessageCopyWith<$Res> {
  factory _$TelegramMessageCopyWith(_TelegramMessage value, $Res Function(_TelegramMessage) _then) = __$TelegramMessageCopyWithImpl;
@override @useResult
$Res call({
 int messageId, int chatId, int senderId, MessageDirection direction, MessageContentType contentType, String text, DateTime date, DateTime? editDate, int? replyToMessageId, bool isRead, bool isSystemMessage, Map<String, dynamic>? metadata, String? filePath, int? fileSize, String? mimeType
});




}
/// @nodoc
class __$TelegramMessageCopyWithImpl<$Res>
    implements _$TelegramMessageCopyWith<$Res> {
  __$TelegramMessageCopyWithImpl(this._self, this._then);

  final _TelegramMessage _self;
  final $Res Function(_TelegramMessage) _then;

/// Create a copy of TelegramMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? chatId = null,Object? senderId = null,Object? direction = null,Object? contentType = null,Object? text = null,Object? date = null,Object? editDate = freezed,Object? replyToMessageId = freezed,Object? isRead = null,Object? isSystemMessage = null,Object? metadata = freezed,Object? filePath = freezed,Object? fileSize = freezed,Object? mimeType = freezed,}) {
  return _then(_TelegramMessage(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as int,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as MessageDirection,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as MessageContentType,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,editDate: freezed == editDate ? _self.editDate : editDate // ignore: cast_nullable_to_non_nullable
as DateTime?,replyToMessageId: freezed == replyToMessageId ? _self.replyToMessageId : replyToMessageId // ignore: cast_nullable_to_non_nullable
as int?,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,isSystemMessage: null == isSystemMessage ? _self.isSystemMessage : isSystemMessage // ignore: cast_nullable_to_non_nullable
as bool,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,filePath: freezed == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String?,fileSize: freezed == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
