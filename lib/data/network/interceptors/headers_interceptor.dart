import 'request_interceptor.dart';

class HeadersInterceptor extends RequestInterceptor {
  HeadersInterceptor({
    this.appVersion = '1.0.0',
    this.deviceId,
    this.posId,
    this.getAuthToken,
  });

  final String appVersion;

  final String? deviceId;

  final int? posId;

  final String? Function()? getAuthToken;

  @override
  String get name => 'HeadersInterceptor';

  @override
  int get priority => 10;

  @override
  Future<NetworkRequest?> onRequest(NetworkRequest request) async {
    var updatedRequest = request;

    updatedRequest = updatedRequest.addHeader('X-App-Version', appVersion);

    if (deviceId != null) {
      updatedRequest = updatedRequest.addHeader('X-Device-Id', deviceId!);
    }

    if (posId != null) {
      updatedRequest = updatedRequest.addHeader('X-Pos-Id', posId.toString());
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    updatedRequest = updatedRequest.addHeader('X-Timestamp', timestamp);

    final token = getAuthToken?.call();
    if (token != null && token.isNotEmpty) {
      updatedRequest = updatedRequest.addHeader(
        'Authorization',
        'Bearer $token',
      );
    }

    if (request.method == 'POST' || request.method == 'PUT') {
      if (!request.headers.containsKey('Content-Type')) {
        updatedRequest = updatedRequest.addHeader(
          'Content-Type',
          'application/json; charset=utf-8',
        );
      }
    }

    updatedRequest = updatedRequest.addHeader('Accept', 'application/json');

    return updatedRequest;
  }
}

class HeadersConfig {
  const HeadersConfig({
    required this.appVersion,
    this.deviceId,
    this.posId,
    this.customHeaders = const {},
  });

  final String appVersion;
  final String? deviceId;
  final int? posId;
  final Map<String, String> customHeaders;

  HeadersInterceptor toInterceptor({String? Function()? getAuthToken}) {
    return HeadersInterceptor(
      appVersion: appVersion,
      deviceId: deviceId,
      posId: posId,
      getAuthToken: getAuthToken,
    );
  }
}
