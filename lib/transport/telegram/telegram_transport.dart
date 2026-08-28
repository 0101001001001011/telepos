import '../interface/transport_interface_exports.dart';

abstract class TelegramTransport implements TransportInterface {
  Future<bool> isAuthorized();

  Future<int?> getCurrentUserId();

  Future<TransportResult<List<String>>> getSystemChannels();

  Future<TransportResult<int>> sendChannelMessage(
    String channelId,
    String message,
  );

  Future<TransportResult<int>> sendChannelFile(
    String channelId,
    String filePath, {
    String? caption,
  });

  Future<TransportResult<String>> createPrivateChannel(
    String title,
    String description,
  );

  Stream<TelegramChannelUpdate> subscribeToChannel(String channelId);
}

class TelegramChannelUpdate {
  final int messageId;

  final String channelId;

  final String? text;

  final int? senderId;

  final DateTime timestamp;

  final bool isSyncData;

  final bool isProtocolMessage;

  const TelegramChannelUpdate({
    required this.messageId,
    required this.channelId,
    this.text,
    this.senderId,
    required this.timestamp,
    this.isSyncData = false,
    this.isProtocolMessage = false,
  });

  bool get isSystemMessage => isSyncData || isProtocolMessage;
}
