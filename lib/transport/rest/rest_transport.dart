import '../interface/transport_interface_exports.dart';

abstract class RestTransport implements TransportInterface {
  Future<bool> isTokenValid();

  Future<TransportResult<String>> refreshAccessToken();

  String? get accessToken;

  set accessToken(String? token);

  String? get refreshToken;

  set refreshToken(String? token);

  Future<TransportResult<Map<String, dynamic>>> registerPos(
    Map<String, dynamic> posInfo,
  );

  Future<TransportResult<Map<String, dynamic>>> loginByCredentials(
    String email,
    String password,
  );

  Future<TransportResult<Map<String, dynamic>>> loginByPin(
    String pin,
    String posId,
  );

  Future<TransportResult<void>> connectWebSocket();

  Future<void> disconnectWebSocket();

  bool get isWebSocketConnected;
}
