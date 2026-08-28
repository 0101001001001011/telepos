import 'package:telepos/domain/entities/telegram/sync_packet.dart';

abstract class IntegrationBridge {
  String get bridgeId;

  BridgeType get bridgeType;

  bool get isConnected;

  Future<void> connect();

  Future<void> disconnect();

  Future<void> sendData(ExchangeType type, Map<String, dynamic> data);

  Stream<BridgeMessage> get incomingData;

  Future<Map<String, dynamic>> requestData(
    ExchangeType type, {
    Map<String, dynamic>? params,
  });

  Future<bool> ping();
}

enum BridgeType { server, oneC, multiPos, erp }

class BridgeMessage {
  final BridgeType source;
  final ExchangeType type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  BridgeMessage({
    required this.source,
    required this.type,
    required this.data,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}
