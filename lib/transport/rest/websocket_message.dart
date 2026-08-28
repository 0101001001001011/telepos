enum WebSocketMessageType {
  subscribe,

  unsubscribe,

  priceUpdate,

  stockUpdate,

  configUpdate,

  remoteCommand,

  ping,

  pong,

  error,

  ack,

  syncRequest,

  notification,
}

class WebSocketMessage {
  final WebSocketMessageType type;

  final String? messageId;

  final String? channel;

  final Map<String, dynamic>? data;

  final DateTime timestamp;

  const WebSocketMessage({
    required this.type,
    this.messageId,
    this.channel,
    this.data,
    required this.timestamp,
  });

  factory WebSocketMessage.ping() {
    return WebSocketMessage(
      type: WebSocketMessageType.ping,
      timestamp: DateTime.now(),
    );
  }

  factory WebSocketMessage.pong() {
    return WebSocketMessage(
      type: WebSocketMessageType.pong,
      timestamp: DateTime.now(),
    );
  }

  factory WebSocketMessage.subscribe(List<String> channels) {
    return WebSocketMessage(
      type: WebSocketMessageType.subscribe,
      data: {'channels': channels},
      timestamp: DateTime.now(),
    );
  }

  factory WebSocketMessage.unsubscribe(List<String> channels) {
    return WebSocketMessage(
      type: WebSocketMessageType.unsubscribe,
      data: {'channels': channels},
      timestamp: DateTime.now(),
    );
  }

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: _parseType(json['type'] as String?),
      messageId: json['messageId'] as String?,
      channel: json['channel'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  static WebSocketMessageType _parseType(String? typeStr) {
    if (typeStr == null) return WebSocketMessageType.error;

    return WebSocketMessageType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => WebSocketMessageType.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (messageId != null) 'messageId': messageId,
      if (channel != null) 'channel': channel,
      if (data != null) 'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isHeartbeat =>
      type == WebSocketMessageType.ping || type == WebSocketMessageType.pong;

  bool get isDataUpdate =>
      type == WebSocketMessageType.priceUpdate ||
      type == WebSocketMessageType.stockUpdate ||
      type == WebSocketMessageType.configUpdate;

  @override
  String toString() =>
      'WebSocketMessage(type: ${type.name}, channel: $channel)';
}

class RemoteCommand {
  final RemoteCommandType type;

  final Map<String, dynamic> params;

  final String commandId;

  final bool requiresAck;

  const RemoteCommand({
    required this.type,
    required this.params,
    required this.commandId,
    this.requiresAck = true,
  });

  factory RemoteCommand.fromJson(Map<String, dynamic> json) {
    return RemoteCommand(
      type: RemoteCommandType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RemoteCommandType.unknown,
      ),
      params: json['params'] as Map<String, dynamic>? ?? {},
      commandId: json['commandId'] as String? ?? '',
      requiresAck: json['requiresAck'] as bool? ?? true,
    );
  }
}

enum RemoteCommandType {
  forceSync,

  updateConfig,

  reloadData,

  lockPos,

  unlockPos,

  sendReport,

  createBackup,

  softwareUpdate,

  unknown,
}
