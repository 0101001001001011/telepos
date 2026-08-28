// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_packet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SyncPacket {

 String get packetId; ExchangeType get exchangeType; String get sourceId; String get targetId; int get sequenceNo; String get payload; int get payloadSize; String get checksum; SyncPacketStatus get status; DateTime get createdAt; DateTime? get sentAt; DateTime? get deliveredAt; DateTime? get acknowledgedAt; int get retryCount; int get maxRetries; bool get isCompressed; bool get isEncrypted; String? get errorMessage;
/// Create a copy of SyncPacket
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncPacketCopyWith<SyncPacket> get copyWith => _$SyncPacketCopyWithImpl<SyncPacket>(this as SyncPacket, _$identity);

  /// Serializes this SyncPacket to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncPacket&&(identical(other.packetId, packetId) || other.packetId == packetId)&&(identical(other.exchangeType, exchangeType) || other.exchangeType == exchangeType)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.sequenceNo, sequenceNo) || other.sequenceNo == sequenceNo)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.payloadSize, payloadSize) || other.payloadSize == payloadSize)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.acknowledgedAt, acknowledgedAt) || other.acknowledgedAt == acknowledgedAt)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries)&&(identical(other.isCompressed, isCompressed) || other.isCompressed == isCompressed)&&(identical(other.isEncrypted, isEncrypted) || other.isEncrypted == isEncrypted)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packetId,exchangeType,sourceId,targetId,sequenceNo,payload,payloadSize,checksum,status,createdAt,sentAt,deliveredAt,acknowledgedAt,retryCount,maxRetries,isCompressed,isEncrypted,errorMessage);

@override
String toString() {
  return 'SyncPacket(packetId: $packetId, exchangeType: $exchangeType, sourceId: $sourceId, targetId: $targetId, sequenceNo: $sequenceNo, payload: $payload, payloadSize: $payloadSize, checksum: $checksum, status: $status, createdAt: $createdAt, sentAt: $sentAt, deliveredAt: $deliveredAt, acknowledgedAt: $acknowledgedAt, retryCount: $retryCount, maxRetries: $maxRetries, isCompressed: $isCompressed, isEncrypted: $isEncrypted, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $SyncPacketCopyWith<$Res>  {
  factory $SyncPacketCopyWith(SyncPacket value, $Res Function(SyncPacket) _then) = _$SyncPacketCopyWithImpl;
@useResult
$Res call({
 String packetId, ExchangeType exchangeType, String sourceId, String targetId, int sequenceNo, String payload, int payloadSize, String checksum, SyncPacketStatus status, DateTime createdAt, DateTime? sentAt, DateTime? deliveredAt, DateTime? acknowledgedAt, int retryCount, int maxRetries, bool isCompressed, bool isEncrypted, String? errorMessage
});




}
/// @nodoc
class _$SyncPacketCopyWithImpl<$Res>
    implements $SyncPacketCopyWith<$Res> {
  _$SyncPacketCopyWithImpl(this._self, this._then);

  final SyncPacket _self;
  final $Res Function(SyncPacket) _then;

/// Create a copy of SyncPacket
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? packetId = null,Object? exchangeType = null,Object? sourceId = null,Object? targetId = null,Object? sequenceNo = null,Object? payload = null,Object? payloadSize = null,Object? checksum = null,Object? status = null,Object? createdAt = null,Object? sentAt = freezed,Object? deliveredAt = freezed,Object? acknowledgedAt = freezed,Object? retryCount = null,Object? maxRetries = null,Object? isCompressed = null,Object? isEncrypted = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
packetId: null == packetId ? _self.packetId : packetId // ignore: cast_nullable_to_non_nullable
as String,exchangeType: null == exchangeType ? _self.exchangeType : exchangeType // ignore: cast_nullable_to_non_nullable
as ExchangeType,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,sequenceNo: null == sequenceNo ? _self.sequenceNo : sequenceNo // ignore: cast_nullable_to_non_nullable
as int,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,payloadSize: null == payloadSize ? _self.payloadSize : payloadSize // ignore: cast_nullable_to_non_nullable
as int,checksum: null == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncPacketStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,acknowledgedAt: freezed == acknowledgedAt ? _self.acknowledgedAt : acknowledgedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,maxRetries: null == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int,isCompressed: null == isCompressed ? _self.isCompressed : isCompressed // ignore: cast_nullable_to_non_nullable
as bool,isEncrypted: null == isEncrypted ? _self.isEncrypted : isEncrypted // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncPacket].
extension SyncPacketPatterns on SyncPacket {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncPacket value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncPacket() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncPacket value)  $default,){
final _that = this;
switch (_that) {
case _SyncPacket():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncPacket value)?  $default,){
final _that = this;
switch (_that) {
case _SyncPacket() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String packetId,  ExchangeType exchangeType,  String sourceId,  String targetId,  int sequenceNo,  String payload,  int payloadSize,  String checksum,  SyncPacketStatus status,  DateTime createdAt,  DateTime? sentAt,  DateTime? deliveredAt,  DateTime? acknowledgedAt,  int retryCount,  int maxRetries,  bool isCompressed,  bool isEncrypted,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncPacket() when $default != null:
return $default(_that.packetId,_that.exchangeType,_that.sourceId,_that.targetId,_that.sequenceNo,_that.payload,_that.payloadSize,_that.checksum,_that.status,_that.createdAt,_that.sentAt,_that.deliveredAt,_that.acknowledgedAt,_that.retryCount,_that.maxRetries,_that.isCompressed,_that.isEncrypted,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String packetId,  ExchangeType exchangeType,  String sourceId,  String targetId,  int sequenceNo,  String payload,  int payloadSize,  String checksum,  SyncPacketStatus status,  DateTime createdAt,  DateTime? sentAt,  DateTime? deliveredAt,  DateTime? acknowledgedAt,  int retryCount,  int maxRetries,  bool isCompressed,  bool isEncrypted,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _SyncPacket():
return $default(_that.packetId,_that.exchangeType,_that.sourceId,_that.targetId,_that.sequenceNo,_that.payload,_that.payloadSize,_that.checksum,_that.status,_that.createdAt,_that.sentAt,_that.deliveredAt,_that.acknowledgedAt,_that.retryCount,_that.maxRetries,_that.isCompressed,_that.isEncrypted,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String packetId,  ExchangeType exchangeType,  String sourceId,  String targetId,  int sequenceNo,  String payload,  int payloadSize,  String checksum,  SyncPacketStatus status,  DateTime createdAt,  DateTime? sentAt,  DateTime? deliveredAt,  DateTime? acknowledgedAt,  int retryCount,  int maxRetries,  bool isCompressed,  bool isEncrypted,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _SyncPacket() when $default != null:
return $default(_that.packetId,_that.exchangeType,_that.sourceId,_that.targetId,_that.sequenceNo,_that.payload,_that.payloadSize,_that.checksum,_that.status,_that.createdAt,_that.sentAt,_that.deliveredAt,_that.acknowledgedAt,_that.retryCount,_that.maxRetries,_that.isCompressed,_that.isEncrypted,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncPacket implements SyncPacket {
  const _SyncPacket({required this.packetId, required this.exchangeType, required this.sourceId, required this.targetId, required this.sequenceNo, required this.payload, required this.payloadSize, required this.checksum, this.status = SyncPacketStatus.pending, required this.createdAt, this.sentAt, this.deliveredAt, this.acknowledgedAt, this.retryCount = 0, this.maxRetries = 5, this.isCompressed = false, this.isEncrypted = false, this.errorMessage});
  factory _SyncPacket.fromJson(Map<String, dynamic> json) => _$SyncPacketFromJson(json);

@override final  String packetId;
@override final  ExchangeType exchangeType;
@override final  String sourceId;
@override final  String targetId;
@override final  int sequenceNo;
@override final  String payload;
@override final  int payloadSize;
@override final  String checksum;
@override@JsonKey() final  SyncPacketStatus status;
@override final  DateTime createdAt;
@override final  DateTime? sentAt;
@override final  DateTime? deliveredAt;
@override final  DateTime? acknowledgedAt;
@override@JsonKey() final  int retryCount;
@override@JsonKey() final  int maxRetries;
@override@JsonKey() final  bool isCompressed;
@override@JsonKey() final  bool isEncrypted;
@override final  String? errorMessage;

/// Create a copy of SyncPacket
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncPacketCopyWith<_SyncPacket> get copyWith => __$SyncPacketCopyWithImpl<_SyncPacket>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncPacketToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncPacket&&(identical(other.packetId, packetId) || other.packetId == packetId)&&(identical(other.exchangeType, exchangeType) || other.exchangeType == exchangeType)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.sequenceNo, sequenceNo) || other.sequenceNo == sequenceNo)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.payloadSize, payloadSize) || other.payloadSize == payloadSize)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.acknowledgedAt, acknowledgedAt) || other.acknowledgedAt == acknowledgedAt)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries)&&(identical(other.isCompressed, isCompressed) || other.isCompressed == isCompressed)&&(identical(other.isEncrypted, isEncrypted) || other.isEncrypted == isEncrypted)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packetId,exchangeType,sourceId,targetId,sequenceNo,payload,payloadSize,checksum,status,createdAt,sentAt,deliveredAt,acknowledgedAt,retryCount,maxRetries,isCompressed,isEncrypted,errorMessage);

@override
String toString() {
  return 'SyncPacket(packetId: $packetId, exchangeType: $exchangeType, sourceId: $sourceId, targetId: $targetId, sequenceNo: $sequenceNo, payload: $payload, payloadSize: $payloadSize, checksum: $checksum, status: $status, createdAt: $createdAt, sentAt: $sentAt, deliveredAt: $deliveredAt, acknowledgedAt: $acknowledgedAt, retryCount: $retryCount, maxRetries: $maxRetries, isCompressed: $isCompressed, isEncrypted: $isEncrypted, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$SyncPacketCopyWith<$Res> implements $SyncPacketCopyWith<$Res> {
  factory _$SyncPacketCopyWith(_SyncPacket value, $Res Function(_SyncPacket) _then) = __$SyncPacketCopyWithImpl;
@override @useResult
$Res call({
 String packetId, ExchangeType exchangeType, String sourceId, String targetId, int sequenceNo, String payload, int payloadSize, String checksum, SyncPacketStatus status, DateTime createdAt, DateTime? sentAt, DateTime? deliveredAt, DateTime? acknowledgedAt, int retryCount, int maxRetries, bool isCompressed, bool isEncrypted, String? errorMessage
});




}
/// @nodoc
class __$SyncPacketCopyWithImpl<$Res>
    implements _$SyncPacketCopyWith<$Res> {
  __$SyncPacketCopyWithImpl(this._self, this._then);

  final _SyncPacket _self;
  final $Res Function(_SyncPacket) _then;

/// Create a copy of SyncPacket
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? packetId = null,Object? exchangeType = null,Object? sourceId = null,Object? targetId = null,Object? sequenceNo = null,Object? payload = null,Object? payloadSize = null,Object? checksum = null,Object? status = null,Object? createdAt = null,Object? sentAt = freezed,Object? deliveredAt = freezed,Object? acknowledgedAt = freezed,Object? retryCount = null,Object? maxRetries = null,Object? isCompressed = null,Object? isEncrypted = null,Object? errorMessage = freezed,}) {
  return _then(_SyncPacket(
packetId: null == packetId ? _self.packetId : packetId // ignore: cast_nullable_to_non_nullable
as String,exchangeType: null == exchangeType ? _self.exchangeType : exchangeType // ignore: cast_nullable_to_non_nullable
as ExchangeType,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,sequenceNo: null == sequenceNo ? _self.sequenceNo : sequenceNo // ignore: cast_nullable_to_non_nullable
as int,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,payloadSize: null == payloadSize ? _self.payloadSize : payloadSize // ignore: cast_nullable_to_non_nullable
as int,checksum: null == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncPacketStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,acknowledgedAt: freezed == acknowledgedAt ? _self.acknowledgedAt : acknowledgedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,maxRetries: null == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int,isCompressed: null == isCompressed ? _self.isCompressed : isCompressed // ignore: cast_nullable_to_non_nullable
as bool,isEncrypted: null == isEncrypted ? _self.isEncrypted : isEncrypted // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
