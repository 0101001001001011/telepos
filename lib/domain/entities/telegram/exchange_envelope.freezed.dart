// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exchange_envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExchangeEnvelope {

 String get packetId; String get sourceId; String get targetId; ExchangeType get type; int get sequenceNo; int get totalChunks; int get chunkIndex; DateTime get timestamp; String get checksum; String get encryptedPayload; String get signature; int get protocolVersion; int get ttlSeconds; bool get requiresAck; int? get telegramMessageId; int? get telegramChatId;
/// Create a copy of ExchangeEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExchangeEnvelopeCopyWith<ExchangeEnvelope> get copyWith => _$ExchangeEnvelopeCopyWithImpl<ExchangeEnvelope>(this as ExchangeEnvelope, _$identity);

  /// Serializes this ExchangeEnvelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExchangeEnvelope&&(identical(other.packetId, packetId) || other.packetId == packetId)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.type, type) || other.type == type)&&(identical(other.sequenceNo, sequenceNo) || other.sequenceNo == sequenceNo)&&(identical(other.totalChunks, totalChunks) || other.totalChunks == totalChunks)&&(identical(other.chunkIndex, chunkIndex) || other.chunkIndex == chunkIndex)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.encryptedPayload, encryptedPayload) || other.encryptedPayload == encryptedPayload)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.ttlSeconds, ttlSeconds) || other.ttlSeconds == ttlSeconds)&&(identical(other.requiresAck, requiresAck) || other.requiresAck == requiresAck)&&(identical(other.telegramMessageId, telegramMessageId) || other.telegramMessageId == telegramMessageId)&&(identical(other.telegramChatId, telegramChatId) || other.telegramChatId == telegramChatId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packetId,sourceId,targetId,type,sequenceNo,totalChunks,chunkIndex,timestamp,checksum,encryptedPayload,signature,protocolVersion,ttlSeconds,requiresAck,telegramMessageId,telegramChatId);

@override
String toString() {
  return 'ExchangeEnvelope(packetId: $packetId, sourceId: $sourceId, targetId: $targetId, type: $type, sequenceNo: $sequenceNo, totalChunks: $totalChunks, chunkIndex: $chunkIndex, timestamp: $timestamp, checksum: $checksum, encryptedPayload: $encryptedPayload, signature: $signature, protocolVersion: $protocolVersion, ttlSeconds: $ttlSeconds, requiresAck: $requiresAck, telegramMessageId: $telegramMessageId, telegramChatId: $telegramChatId)';
}


}

/// @nodoc
abstract mixin class $ExchangeEnvelopeCopyWith<$Res>  {
  factory $ExchangeEnvelopeCopyWith(ExchangeEnvelope value, $Res Function(ExchangeEnvelope) _then) = _$ExchangeEnvelopeCopyWithImpl;
@useResult
$Res call({
 String packetId, String sourceId, String targetId, ExchangeType type, int sequenceNo, int totalChunks, int chunkIndex, DateTime timestamp, String checksum, String encryptedPayload, String signature, int protocolVersion, int ttlSeconds, bool requiresAck, int? telegramMessageId, int? telegramChatId
});




}
/// @nodoc
class _$ExchangeEnvelopeCopyWithImpl<$Res>
    implements $ExchangeEnvelopeCopyWith<$Res> {
  _$ExchangeEnvelopeCopyWithImpl(this._self, this._then);

  final ExchangeEnvelope _self;
  final $Res Function(ExchangeEnvelope) _then;

/// Create a copy of ExchangeEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? packetId = null,Object? sourceId = null,Object? targetId = null,Object? type = null,Object? sequenceNo = null,Object? totalChunks = null,Object? chunkIndex = null,Object? timestamp = null,Object? checksum = null,Object? encryptedPayload = null,Object? signature = null,Object? protocolVersion = null,Object? ttlSeconds = null,Object? requiresAck = null,Object? telegramMessageId = freezed,Object? telegramChatId = freezed,}) {
  return _then(_self.copyWith(
packetId: null == packetId ? _self.packetId : packetId // ignore: cast_nullable_to_non_nullable
as String,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ExchangeType,sequenceNo: null == sequenceNo ? _self.sequenceNo : sequenceNo // ignore: cast_nullable_to_non_nullable
as int,totalChunks: null == totalChunks ? _self.totalChunks : totalChunks // ignore: cast_nullable_to_non_nullable
as int,chunkIndex: null == chunkIndex ? _self.chunkIndex : chunkIndex // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,checksum: null == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String,encryptedPayload: null == encryptedPayload ? _self.encryptedPayload : encryptedPayload // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,ttlSeconds: null == ttlSeconds ? _self.ttlSeconds : ttlSeconds // ignore: cast_nullable_to_non_nullable
as int,requiresAck: null == requiresAck ? _self.requiresAck : requiresAck // ignore: cast_nullable_to_non_nullable
as bool,telegramMessageId: freezed == telegramMessageId ? _self.telegramMessageId : telegramMessageId // ignore: cast_nullable_to_non_nullable
as int?,telegramChatId: freezed == telegramChatId ? _self.telegramChatId : telegramChatId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExchangeEnvelope].
extension ExchangeEnvelopePatterns on ExchangeEnvelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExchangeEnvelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExchangeEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExchangeEnvelope value)  $default,){
final _that = this;
switch (_that) {
case _ExchangeEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExchangeEnvelope value)?  $default,){
final _that = this;
switch (_that) {
case _ExchangeEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String packetId,  String sourceId,  String targetId,  ExchangeType type,  int sequenceNo,  int totalChunks,  int chunkIndex,  DateTime timestamp,  String checksum,  String encryptedPayload,  String signature,  int protocolVersion,  int ttlSeconds,  bool requiresAck,  int? telegramMessageId,  int? telegramChatId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExchangeEnvelope() when $default != null:
return $default(_that.packetId,_that.sourceId,_that.targetId,_that.type,_that.sequenceNo,_that.totalChunks,_that.chunkIndex,_that.timestamp,_that.checksum,_that.encryptedPayload,_that.signature,_that.protocolVersion,_that.ttlSeconds,_that.requiresAck,_that.telegramMessageId,_that.telegramChatId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String packetId,  String sourceId,  String targetId,  ExchangeType type,  int sequenceNo,  int totalChunks,  int chunkIndex,  DateTime timestamp,  String checksum,  String encryptedPayload,  String signature,  int protocolVersion,  int ttlSeconds,  bool requiresAck,  int? telegramMessageId,  int? telegramChatId)  $default,) {final _that = this;
switch (_that) {
case _ExchangeEnvelope():
return $default(_that.packetId,_that.sourceId,_that.targetId,_that.type,_that.sequenceNo,_that.totalChunks,_that.chunkIndex,_that.timestamp,_that.checksum,_that.encryptedPayload,_that.signature,_that.protocolVersion,_that.ttlSeconds,_that.requiresAck,_that.telegramMessageId,_that.telegramChatId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String packetId,  String sourceId,  String targetId,  ExchangeType type,  int sequenceNo,  int totalChunks,  int chunkIndex,  DateTime timestamp,  String checksum,  String encryptedPayload,  String signature,  int protocolVersion,  int ttlSeconds,  bool requiresAck,  int? telegramMessageId,  int? telegramChatId)?  $default,) {final _that = this;
switch (_that) {
case _ExchangeEnvelope() when $default != null:
return $default(_that.packetId,_that.sourceId,_that.targetId,_that.type,_that.sequenceNo,_that.totalChunks,_that.chunkIndex,_that.timestamp,_that.checksum,_that.encryptedPayload,_that.signature,_that.protocolVersion,_that.ttlSeconds,_that.requiresAck,_that.telegramMessageId,_that.telegramChatId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExchangeEnvelope implements ExchangeEnvelope {
  const _ExchangeEnvelope({required this.packetId, required this.sourceId, required this.targetId, required this.type, required this.sequenceNo, this.totalChunks = 1, this.chunkIndex = 0, required this.timestamp, required this.checksum, required this.encryptedPayload, required this.signature, this.protocolVersion = 1, this.ttlSeconds = 0, this.requiresAck = true, this.telegramMessageId, this.telegramChatId});
  factory _ExchangeEnvelope.fromJson(Map<String, dynamic> json) => _$ExchangeEnvelopeFromJson(json);

@override final  String packetId;
@override final  String sourceId;
@override final  String targetId;
@override final  ExchangeType type;
@override final  int sequenceNo;
@override@JsonKey() final  int totalChunks;
@override@JsonKey() final  int chunkIndex;
@override final  DateTime timestamp;
@override final  String checksum;
@override final  String encryptedPayload;
@override final  String signature;
@override@JsonKey() final  int protocolVersion;
@override@JsonKey() final  int ttlSeconds;
@override@JsonKey() final  bool requiresAck;
@override final  int? telegramMessageId;
@override final  int? telegramChatId;

/// Create a copy of ExchangeEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExchangeEnvelopeCopyWith<_ExchangeEnvelope> get copyWith => __$ExchangeEnvelopeCopyWithImpl<_ExchangeEnvelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExchangeEnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExchangeEnvelope&&(identical(other.packetId, packetId) || other.packetId == packetId)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.type, type) || other.type == type)&&(identical(other.sequenceNo, sequenceNo) || other.sequenceNo == sequenceNo)&&(identical(other.totalChunks, totalChunks) || other.totalChunks == totalChunks)&&(identical(other.chunkIndex, chunkIndex) || other.chunkIndex == chunkIndex)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.encryptedPayload, encryptedPayload) || other.encryptedPayload == encryptedPayload)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.ttlSeconds, ttlSeconds) || other.ttlSeconds == ttlSeconds)&&(identical(other.requiresAck, requiresAck) || other.requiresAck == requiresAck)&&(identical(other.telegramMessageId, telegramMessageId) || other.telegramMessageId == telegramMessageId)&&(identical(other.telegramChatId, telegramChatId) || other.telegramChatId == telegramChatId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packetId,sourceId,targetId,type,sequenceNo,totalChunks,chunkIndex,timestamp,checksum,encryptedPayload,signature,protocolVersion,ttlSeconds,requiresAck,telegramMessageId,telegramChatId);

@override
String toString() {
  return 'ExchangeEnvelope(packetId: $packetId, sourceId: $sourceId, targetId: $targetId, type: $type, sequenceNo: $sequenceNo, totalChunks: $totalChunks, chunkIndex: $chunkIndex, timestamp: $timestamp, checksum: $checksum, encryptedPayload: $encryptedPayload, signature: $signature, protocolVersion: $protocolVersion, ttlSeconds: $ttlSeconds, requiresAck: $requiresAck, telegramMessageId: $telegramMessageId, telegramChatId: $telegramChatId)';
}


}

/// @nodoc
abstract mixin class _$ExchangeEnvelopeCopyWith<$Res> implements $ExchangeEnvelopeCopyWith<$Res> {
  factory _$ExchangeEnvelopeCopyWith(_ExchangeEnvelope value, $Res Function(_ExchangeEnvelope) _then) = __$ExchangeEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 String packetId, String sourceId, String targetId, ExchangeType type, int sequenceNo, int totalChunks, int chunkIndex, DateTime timestamp, String checksum, String encryptedPayload, String signature, int protocolVersion, int ttlSeconds, bool requiresAck, int? telegramMessageId, int? telegramChatId
});




}
/// @nodoc
class __$ExchangeEnvelopeCopyWithImpl<$Res>
    implements _$ExchangeEnvelopeCopyWith<$Res> {
  __$ExchangeEnvelopeCopyWithImpl(this._self, this._then);

  final _ExchangeEnvelope _self;
  final $Res Function(_ExchangeEnvelope) _then;

/// Create a copy of ExchangeEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? packetId = null,Object? sourceId = null,Object? targetId = null,Object? type = null,Object? sequenceNo = null,Object? totalChunks = null,Object? chunkIndex = null,Object? timestamp = null,Object? checksum = null,Object? encryptedPayload = null,Object? signature = null,Object? protocolVersion = null,Object? ttlSeconds = null,Object? requiresAck = null,Object? telegramMessageId = freezed,Object? telegramChatId = freezed,}) {
  return _then(_ExchangeEnvelope(
packetId: null == packetId ? _self.packetId : packetId // ignore: cast_nullable_to_non_nullable
as String,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ExchangeType,sequenceNo: null == sequenceNo ? _self.sequenceNo : sequenceNo // ignore: cast_nullable_to_non_nullable
as int,totalChunks: null == totalChunks ? _self.totalChunks : totalChunks // ignore: cast_nullable_to_non_nullable
as int,chunkIndex: null == chunkIndex ? _self.chunkIndex : chunkIndex // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,checksum: null == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String,encryptedPayload: null == encryptedPayload ? _self.encryptedPayload : encryptedPayload // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,ttlSeconds: null == ttlSeconds ? _self.ttlSeconds : ttlSeconds // ignore: cast_nullable_to_non_nullable
as int,requiresAck: null == requiresAck ? _self.requiresAck : requiresAck // ignore: cast_nullable_to_non_nullable
as bool,telegramMessageId: freezed == telegramMessageId ? _self.telegramMessageId : telegramMessageId // ignore: cast_nullable_to_non_nullable
as int?,telegramChatId: freezed == telegramChatId ? _self.telegramChatId : telegramChatId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
