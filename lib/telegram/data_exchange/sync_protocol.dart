import 'package:telepos/domain/entities/telegram/sync_packet.dart';

enum ProtocolCommand {
  handshake,

  handshakeAck,

  data,

  ack,

  nack,

  complete,

  heartbeat,

  heartbeatAck,

  resend,

  cancel,
}

class ProtocolMessage {
  final ProtocolCommand command;
  final String sessionId;
  final int sequenceNo;
  final ExchangeType? exchangeType;
  final String? payload;
  final Map<String, dynamic>? metadata;

  ProtocolMessage({
    required this.command,
    required this.sessionId,
    required this.sequenceNo,
    this.exchangeType,
    this.payload,
    this.metadata,
  });

  factory ProtocolMessage.handshake({
    required String sessionId,
    required String sourceId,
    required int protocolVersion,
    required List<ExchangeType> supportedTypes,
  }) {
    return ProtocolMessage(
      command: ProtocolCommand.handshake,
      sessionId: sessionId,
      sequenceNo: 0,
      metadata: {
        'sourceId': sourceId,
        'protocolVersion': protocolVersion,
        'supportedTypes': supportedTypes.map((t) => t.name).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  factory ProtocolMessage.ack({
    required String sessionId,
    required int sequenceNo,
  }) {
    return ProtocolMessage(
      command: ProtocolCommand.ack,
      sessionId: sessionId,
      sequenceNo: sequenceNo,
    );
  }

  factory ProtocolMessage.heartbeat({required String sessionId}) {
    return ProtocolMessage(
      command: ProtocolCommand.heartbeat,
      sessionId: sessionId,
      sequenceNo: -1,
      metadata: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  String serialize() {
    final parts = <String>[
      '__TELEPOS_PROTO__',
      command.name,
      sessionId,
      sequenceNo.toString(),
      exchangeType?.name ?? '',
      payload ?? '',
    ];
    return parts.join('|');
  }

  static ProtocolMessage? deserialize(String data) {
    if (!data.startsWith('__TELEPOS_PROTO__')) return null;

    final parts = data.split('|');
    if (parts.length < 4) return null;

    return ProtocolMessage(
      command: ProtocolCommand.values.firstWhere(
        (c) => c.name == parts[1],
        orElse: () => ProtocolCommand.heartbeat,
      ),
      sessionId: parts[2],
      sequenceNo: int.tryParse(parts[3]) ?? 0,
      exchangeType: parts.length > 4 && parts[4].isNotEmpty
          ? ExchangeType.values.firstWhere(
              (t) => t.name == parts[4],
              orElse: () => ExchangeType.fullSync,
            )
          : null,
      payload: parts.length > 5 ? parts[5] : null,
    );
  }
}

enum SyncSessionState {
  idle,
  handshaking,
  active,
  completing,
  completed,
  failed,
  cancelled,
}

class SyncSession {
  final String sessionId;
  final String peerId;
  final DateTime startedAt;
  SyncSessionState state;
  int lastSequenceNo;
  int totalPackets;
  int deliveredPackets;

  SyncSession({
    required this.sessionId,
    required this.peerId,
    required this.startedAt,
    this.state = SyncSessionState.idle,
    this.lastSequenceNo = 0,
    this.totalPackets = 0,
    this.deliveredPackets = 0,
  });

  double get progress =>
      totalPackets > 0 ? deliveredPackets / totalPackets : 0.0;

  bool get isComplete => state == SyncSessionState.completed;
  bool get isFailed => state == SyncSessionState.failed;
}
