class MTProtoConfig {
  final bool usePfs;

  final int sessionKeyTtlSeconds;

  final int maxDcConnections;

  final bool useTcpTransport;

  final bool preferIpv6;

  final MTProtoProxy? proxy;

  const MTProtoConfig({
    this.usePfs = true,
    this.sessionKeyTtlSeconds = 86400,
    this.maxDcConnections = 4,
    this.useTcpTransport = true,
    this.preferIpv6 = false,
    this.proxy,
  });

  static const MTProtoConfig defaultConfig = MTProtoConfig();

  Map<String, dynamic> toTdLibParams() => {
    'enable_storage_optimizer': true,
    'ignore_background_updates': false,
  };
}

class MTProtoProxy {
  final String server;
  final int port;
  final MTProtoProxyType type;
  final String? username;
  final String? password;
  final String? secret;

  const MTProtoProxy({
    required this.server,
    required this.port,
    required this.type,
    this.username,
    this.password,
    this.secret,
  });

  Map<String, dynamic> toTdLibParams() {
    switch (type) {
      case MTProtoProxyType.socks5:
        return {
          '@type': 'proxyTypeSocks5',
          'username': username ?? '',
          'password': password ?? '',
        };
      case MTProtoProxyType.http:
        return {
          '@type': 'proxyTypeHttp',
          'username': username ?? '',
          'password': password ?? '',
          'http_only': false,
        };
      case MTProtoProxyType.mtproto:
        return {'@type': 'proxyTypeMtproto', 'secret': secret ?? ''};
    }
  }
}

enum MTProtoProxyType { socks5, http, mtproto }
