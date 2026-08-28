// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telegram_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TelegramConfig {

 int get apiId; String get apiHash; String get databaseDirectory; String get filesDirectory; bool get useTestDc; int get logVerbosityLevel; String get deviceModel; String get systemVersion; String get applicationVersion; String get systemLanguageCode; bool get enableStorageEncryption; String? get storageEncryptionKey; bool get useFileDatabase; bool get useChatInfoDatabase; bool get useMessageDatabase; String? get posId; String? get storeName;
/// Create a copy of TelegramConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelegramConfigCopyWith<TelegramConfig> get copyWith => _$TelegramConfigCopyWithImpl<TelegramConfig>(this as TelegramConfig, _$identity);

  /// Serializes this TelegramConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelegramConfig&&(identical(other.apiId, apiId) || other.apiId == apiId)&&(identical(other.apiHash, apiHash) || other.apiHash == apiHash)&&(identical(other.databaseDirectory, databaseDirectory) || other.databaseDirectory == databaseDirectory)&&(identical(other.filesDirectory, filesDirectory) || other.filesDirectory == filesDirectory)&&(identical(other.useTestDc, useTestDc) || other.useTestDc == useTestDc)&&(identical(other.logVerbosityLevel, logVerbosityLevel) || other.logVerbosityLevel == logVerbosityLevel)&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel)&&(identical(other.systemVersion, systemVersion) || other.systemVersion == systemVersion)&&(identical(other.applicationVersion, applicationVersion) || other.applicationVersion == applicationVersion)&&(identical(other.systemLanguageCode, systemLanguageCode) || other.systemLanguageCode == systemLanguageCode)&&(identical(other.enableStorageEncryption, enableStorageEncryption) || other.enableStorageEncryption == enableStorageEncryption)&&(identical(other.storageEncryptionKey, storageEncryptionKey) || other.storageEncryptionKey == storageEncryptionKey)&&(identical(other.useFileDatabase, useFileDatabase) || other.useFileDatabase == useFileDatabase)&&(identical(other.useChatInfoDatabase, useChatInfoDatabase) || other.useChatInfoDatabase == useChatInfoDatabase)&&(identical(other.useMessageDatabase, useMessageDatabase) || other.useMessageDatabase == useMessageDatabase)&&(identical(other.posId, posId) || other.posId == posId)&&(identical(other.storeName, storeName) || other.storeName == storeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiId,apiHash,databaseDirectory,filesDirectory,useTestDc,logVerbosityLevel,deviceModel,systemVersion,applicationVersion,systemLanguageCode,enableStorageEncryption,storageEncryptionKey,useFileDatabase,useChatInfoDatabase,useMessageDatabase,posId,storeName);

@override
String toString() {
  return 'TelegramConfig(apiId: $apiId, apiHash: $apiHash, databaseDirectory: $databaseDirectory, filesDirectory: $filesDirectory, useTestDc: $useTestDc, logVerbosityLevel: $logVerbosityLevel, deviceModel: $deviceModel, systemVersion: $systemVersion, applicationVersion: $applicationVersion, systemLanguageCode: $systemLanguageCode, enableStorageEncryption: $enableStorageEncryption, storageEncryptionKey: $storageEncryptionKey, useFileDatabase: $useFileDatabase, useChatInfoDatabase: $useChatInfoDatabase, useMessageDatabase: $useMessageDatabase, posId: $posId, storeName: $storeName)';
}


}

/// @nodoc
abstract mixin class $TelegramConfigCopyWith<$Res>  {
  factory $TelegramConfigCopyWith(TelegramConfig value, $Res Function(TelegramConfig) _then) = _$TelegramConfigCopyWithImpl;
@useResult
$Res call({
 int apiId, String apiHash, String databaseDirectory, String filesDirectory, bool useTestDc, int logVerbosityLevel, String deviceModel, String systemVersion, String applicationVersion, String systemLanguageCode, bool enableStorageEncryption, String? storageEncryptionKey, bool useFileDatabase, bool useChatInfoDatabase, bool useMessageDatabase, String? posId, String? storeName
});




}
/// @nodoc
class _$TelegramConfigCopyWithImpl<$Res>
    implements $TelegramConfigCopyWith<$Res> {
  _$TelegramConfigCopyWithImpl(this._self, this._then);

  final TelegramConfig _self;
  final $Res Function(TelegramConfig) _then;

/// Create a copy of TelegramConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiId = null,Object? apiHash = null,Object? databaseDirectory = null,Object? filesDirectory = null,Object? useTestDc = null,Object? logVerbosityLevel = null,Object? deviceModel = null,Object? systemVersion = null,Object? applicationVersion = null,Object? systemLanguageCode = null,Object? enableStorageEncryption = null,Object? storageEncryptionKey = freezed,Object? useFileDatabase = null,Object? useChatInfoDatabase = null,Object? useMessageDatabase = null,Object? posId = freezed,Object? storeName = freezed,}) {
  return _then(_self.copyWith(
apiId: null == apiId ? _self.apiId : apiId // ignore: cast_nullable_to_non_nullable
as int,apiHash: null == apiHash ? _self.apiHash : apiHash // ignore: cast_nullable_to_non_nullable
as String,databaseDirectory: null == databaseDirectory ? _self.databaseDirectory : databaseDirectory // ignore: cast_nullable_to_non_nullable
as String,filesDirectory: null == filesDirectory ? _self.filesDirectory : filesDirectory // ignore: cast_nullable_to_non_nullable
as String,useTestDc: null == useTestDc ? _self.useTestDc : useTestDc // ignore: cast_nullable_to_non_nullable
as bool,logVerbosityLevel: null == logVerbosityLevel ? _self.logVerbosityLevel : logVerbosityLevel // ignore: cast_nullable_to_non_nullable
as int,deviceModel: null == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String,systemVersion: null == systemVersion ? _self.systemVersion : systemVersion // ignore: cast_nullable_to_non_nullable
as String,applicationVersion: null == applicationVersion ? _self.applicationVersion : applicationVersion // ignore: cast_nullable_to_non_nullable
as String,systemLanguageCode: null == systemLanguageCode ? _self.systemLanguageCode : systemLanguageCode // ignore: cast_nullable_to_non_nullable
as String,enableStorageEncryption: null == enableStorageEncryption ? _self.enableStorageEncryption : enableStorageEncryption // ignore: cast_nullable_to_non_nullable
as bool,storageEncryptionKey: freezed == storageEncryptionKey ? _self.storageEncryptionKey : storageEncryptionKey // ignore: cast_nullable_to_non_nullable
as String?,useFileDatabase: null == useFileDatabase ? _self.useFileDatabase : useFileDatabase // ignore: cast_nullable_to_non_nullable
as bool,useChatInfoDatabase: null == useChatInfoDatabase ? _self.useChatInfoDatabase : useChatInfoDatabase // ignore: cast_nullable_to_non_nullable
as bool,useMessageDatabase: null == useMessageDatabase ? _self.useMessageDatabase : useMessageDatabase // ignore: cast_nullable_to_non_nullable
as bool,posId: freezed == posId ? _self.posId : posId // ignore: cast_nullable_to_non_nullable
as String?,storeName: freezed == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TelegramConfig].
extension TelegramConfigPatterns on TelegramConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TelegramConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TelegramConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TelegramConfig value)  $default,){
final _that = this;
switch (_that) {
case _TelegramConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TelegramConfig value)?  $default,){
final _that = this;
switch (_that) {
case _TelegramConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int apiId,  String apiHash,  String databaseDirectory,  String filesDirectory,  bool useTestDc,  int logVerbosityLevel,  String deviceModel,  String systemVersion,  String applicationVersion,  String systemLanguageCode,  bool enableStorageEncryption,  String? storageEncryptionKey,  bool useFileDatabase,  bool useChatInfoDatabase,  bool useMessageDatabase,  String? posId,  String? storeName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TelegramConfig() when $default != null:
return $default(_that.apiId,_that.apiHash,_that.databaseDirectory,_that.filesDirectory,_that.useTestDc,_that.logVerbosityLevel,_that.deviceModel,_that.systemVersion,_that.applicationVersion,_that.systemLanguageCode,_that.enableStorageEncryption,_that.storageEncryptionKey,_that.useFileDatabase,_that.useChatInfoDatabase,_that.useMessageDatabase,_that.posId,_that.storeName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int apiId,  String apiHash,  String databaseDirectory,  String filesDirectory,  bool useTestDc,  int logVerbosityLevel,  String deviceModel,  String systemVersion,  String applicationVersion,  String systemLanguageCode,  bool enableStorageEncryption,  String? storageEncryptionKey,  bool useFileDatabase,  bool useChatInfoDatabase,  bool useMessageDatabase,  String? posId,  String? storeName)  $default,) {final _that = this;
switch (_that) {
case _TelegramConfig():
return $default(_that.apiId,_that.apiHash,_that.databaseDirectory,_that.filesDirectory,_that.useTestDc,_that.logVerbosityLevel,_that.deviceModel,_that.systemVersion,_that.applicationVersion,_that.systemLanguageCode,_that.enableStorageEncryption,_that.storageEncryptionKey,_that.useFileDatabase,_that.useChatInfoDatabase,_that.useMessageDatabase,_that.posId,_that.storeName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int apiId,  String apiHash,  String databaseDirectory,  String filesDirectory,  bool useTestDc,  int logVerbosityLevel,  String deviceModel,  String systemVersion,  String applicationVersion,  String systemLanguageCode,  bool enableStorageEncryption,  String? storageEncryptionKey,  bool useFileDatabase,  bool useChatInfoDatabase,  bool useMessageDatabase,  String? posId,  String? storeName)?  $default,) {final _that = this;
switch (_that) {
case _TelegramConfig() when $default != null:
return $default(_that.apiId,_that.apiHash,_that.databaseDirectory,_that.filesDirectory,_that.useTestDc,_that.logVerbosityLevel,_that.deviceModel,_that.systemVersion,_that.applicationVersion,_that.systemLanguageCode,_that.enableStorageEncryption,_that.storageEncryptionKey,_that.useFileDatabase,_that.useChatInfoDatabase,_that.useMessageDatabase,_that.posId,_that.storeName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TelegramConfig implements TelegramConfig {
  const _TelegramConfig({required this.apiId, required this.apiHash, required this.databaseDirectory, required this.filesDirectory, this.useTestDc = false, this.logVerbosityLevel = 2, this.deviceModel = 'TelePOS Terminal', this.systemVersion = '', this.applicationVersion = '1.0.0', this.systemLanguageCode = 'ru', this.enableStorageEncryption = true, this.storageEncryptionKey, this.useFileDatabase = true, this.useChatInfoDatabase = true, this.useMessageDatabase = true, this.posId, this.storeName});
  factory _TelegramConfig.fromJson(Map<String, dynamic> json) => _$TelegramConfigFromJson(json);

@override final  int apiId;
@override final  String apiHash;
@override final  String databaseDirectory;
@override final  String filesDirectory;
@override@JsonKey() final  bool useTestDc;
@override@JsonKey() final  int logVerbosityLevel;
@override@JsonKey() final  String deviceModel;
@override@JsonKey() final  String systemVersion;
@override@JsonKey() final  String applicationVersion;
@override@JsonKey() final  String systemLanguageCode;
@override@JsonKey() final  bool enableStorageEncryption;
@override final  String? storageEncryptionKey;
@override@JsonKey() final  bool useFileDatabase;
@override@JsonKey() final  bool useChatInfoDatabase;
@override@JsonKey() final  bool useMessageDatabase;
@override final  String? posId;
@override final  String? storeName;

/// Create a copy of TelegramConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TelegramConfigCopyWith<_TelegramConfig> get copyWith => __$TelegramConfigCopyWithImpl<_TelegramConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TelegramConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TelegramConfig&&(identical(other.apiId, apiId) || other.apiId == apiId)&&(identical(other.apiHash, apiHash) || other.apiHash == apiHash)&&(identical(other.databaseDirectory, databaseDirectory) || other.databaseDirectory == databaseDirectory)&&(identical(other.filesDirectory, filesDirectory) || other.filesDirectory == filesDirectory)&&(identical(other.useTestDc, useTestDc) || other.useTestDc == useTestDc)&&(identical(other.logVerbosityLevel, logVerbosityLevel) || other.logVerbosityLevel == logVerbosityLevel)&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel)&&(identical(other.systemVersion, systemVersion) || other.systemVersion == systemVersion)&&(identical(other.applicationVersion, applicationVersion) || other.applicationVersion == applicationVersion)&&(identical(other.systemLanguageCode, systemLanguageCode) || other.systemLanguageCode == systemLanguageCode)&&(identical(other.enableStorageEncryption, enableStorageEncryption) || other.enableStorageEncryption == enableStorageEncryption)&&(identical(other.storageEncryptionKey, storageEncryptionKey) || other.storageEncryptionKey == storageEncryptionKey)&&(identical(other.useFileDatabase, useFileDatabase) || other.useFileDatabase == useFileDatabase)&&(identical(other.useChatInfoDatabase, useChatInfoDatabase) || other.useChatInfoDatabase == useChatInfoDatabase)&&(identical(other.useMessageDatabase, useMessageDatabase) || other.useMessageDatabase == useMessageDatabase)&&(identical(other.posId, posId) || other.posId == posId)&&(identical(other.storeName, storeName) || other.storeName == storeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiId,apiHash,databaseDirectory,filesDirectory,useTestDc,logVerbosityLevel,deviceModel,systemVersion,applicationVersion,systemLanguageCode,enableStorageEncryption,storageEncryptionKey,useFileDatabase,useChatInfoDatabase,useMessageDatabase,posId,storeName);

@override
String toString() {
  return 'TelegramConfig(apiId: $apiId, apiHash: $apiHash, databaseDirectory: $databaseDirectory, filesDirectory: $filesDirectory, useTestDc: $useTestDc, logVerbosityLevel: $logVerbosityLevel, deviceModel: $deviceModel, systemVersion: $systemVersion, applicationVersion: $applicationVersion, systemLanguageCode: $systemLanguageCode, enableStorageEncryption: $enableStorageEncryption, storageEncryptionKey: $storageEncryptionKey, useFileDatabase: $useFileDatabase, useChatInfoDatabase: $useChatInfoDatabase, useMessageDatabase: $useMessageDatabase, posId: $posId, storeName: $storeName)';
}


}

/// @nodoc
abstract mixin class _$TelegramConfigCopyWith<$Res> implements $TelegramConfigCopyWith<$Res> {
  factory _$TelegramConfigCopyWith(_TelegramConfig value, $Res Function(_TelegramConfig) _then) = __$TelegramConfigCopyWithImpl;
@override @useResult
$Res call({
 int apiId, String apiHash, String databaseDirectory, String filesDirectory, bool useTestDc, int logVerbosityLevel, String deviceModel, String systemVersion, String applicationVersion, String systemLanguageCode, bool enableStorageEncryption, String? storageEncryptionKey, bool useFileDatabase, bool useChatInfoDatabase, bool useMessageDatabase, String? posId, String? storeName
});




}
/// @nodoc
class __$TelegramConfigCopyWithImpl<$Res>
    implements _$TelegramConfigCopyWith<$Res> {
  __$TelegramConfigCopyWithImpl(this._self, this._then);

  final _TelegramConfig _self;
  final $Res Function(_TelegramConfig) _then;

/// Create a copy of TelegramConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiId = null,Object? apiHash = null,Object? databaseDirectory = null,Object? filesDirectory = null,Object? useTestDc = null,Object? logVerbosityLevel = null,Object? deviceModel = null,Object? systemVersion = null,Object? applicationVersion = null,Object? systemLanguageCode = null,Object? enableStorageEncryption = null,Object? storageEncryptionKey = freezed,Object? useFileDatabase = null,Object? useChatInfoDatabase = null,Object? useMessageDatabase = null,Object? posId = freezed,Object? storeName = freezed,}) {
  return _then(_TelegramConfig(
apiId: null == apiId ? _self.apiId : apiId // ignore: cast_nullable_to_non_nullable
as int,apiHash: null == apiHash ? _self.apiHash : apiHash // ignore: cast_nullable_to_non_nullable
as String,databaseDirectory: null == databaseDirectory ? _self.databaseDirectory : databaseDirectory // ignore: cast_nullable_to_non_nullable
as String,filesDirectory: null == filesDirectory ? _self.filesDirectory : filesDirectory // ignore: cast_nullable_to_non_nullable
as String,useTestDc: null == useTestDc ? _self.useTestDc : useTestDc // ignore: cast_nullable_to_non_nullable
as bool,logVerbosityLevel: null == logVerbosityLevel ? _self.logVerbosityLevel : logVerbosityLevel // ignore: cast_nullable_to_non_nullable
as int,deviceModel: null == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String,systemVersion: null == systemVersion ? _self.systemVersion : systemVersion // ignore: cast_nullable_to_non_nullable
as String,applicationVersion: null == applicationVersion ? _self.applicationVersion : applicationVersion // ignore: cast_nullable_to_non_nullable
as String,systemLanguageCode: null == systemLanguageCode ? _self.systemLanguageCode : systemLanguageCode // ignore: cast_nullable_to_non_nullable
as String,enableStorageEncryption: null == enableStorageEncryption ? _self.enableStorageEncryption : enableStorageEncryption // ignore: cast_nullable_to_non_nullable
as bool,storageEncryptionKey: freezed == storageEncryptionKey ? _self.storageEncryptionKey : storageEncryptionKey // ignore: cast_nullable_to_non_nullable
as String?,useFileDatabase: null == useFileDatabase ? _self.useFileDatabase : useFileDatabase // ignore: cast_nullable_to_non_nullable
as bool,useChatInfoDatabase: null == useChatInfoDatabase ? _self.useChatInfoDatabase : useChatInfoDatabase // ignore: cast_nullable_to_non_nullable
as bool,useMessageDatabase: null == useMessageDatabase ? _self.useMessageDatabase : useMessageDatabase // ignore: cast_nullable_to_non_nullable
as bool,posId: freezed == posId ? _self.posId : posId // ignore: cast_nullable_to_non_nullable
as String?,storeName: freezed == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
