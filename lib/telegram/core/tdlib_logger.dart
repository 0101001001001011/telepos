import 'package:talker/talker.dart';

class TdLibLogger {
  final Talker _talker;

  TdLibLogger({Talker? talker})
    : _talker = talker ?? Talker(settings: TalkerSettings(enabled: true));

  Talker get talker => _talker;

  void logUpdate(String updateType, [Map<String, dynamic>? data]) {
    _talker.verbose('TDLib update: $updateType', data.toString());
  }

  void logRequest(String method, [Map<String, dynamic>? params]) {
    _talker.info('TDLib request: $method');
  }

  void logResponse(String method, [Map<String, dynamic>? result]) {
    _talker.info('TDLib response: $method');
  }

  void logError(String context, Object error, [StackTrace? stackTrace]) {
    _talker.error('TDLib error in $context', error, stackTrace);
  }

  void logAuthState(String state) {
    _talker.warning('TDLib auth state: $state');
  }

  void logConnection(String event) {
    _talker.info('TDLib connection: $event');
  }

  void logSync(String event, {String? packetId}) {
    final msg = packetId != null ? '$event [packet=$packetId]' : event;
    _talker.info('TDLib sync: $msg');
  }

  void logEncryption(String event) {
    _talker.verbose('TDLib encryption: $event');
  }

  void logCritical(String message, [Object? error, StackTrace? stackTrace]) {
    _talker.critical('TDLib CRITICAL: $message', error, stackTrace);
  }

  void logWarning(String message) {
    _talker.warning('TDLib warning: $message');
  }

  void setVerbosity(int level) {
    _talker.info('TDLib verbosity set to $level');
  }
}
