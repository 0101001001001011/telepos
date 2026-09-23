import 'package:meta/meta.dart';

/// Одна сеть, найденная сканированием Wi-Fi — тот же перенос из
/// `lib/data/sysd/sysd_client.dart`, что и `NetworkStatus`
/// (`network_status.dart`, см. его докстринг).
@immutable
class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.security,
  });

  final String ssid;

  /// Сила сигнала в процентах (0–100), как её отдаёт `nmcli`.
  final int signal;

  /// Пусто — сеть открыта. Непусто — протокол защиты (`WPA2` и т.п.), сам
  /// текст на экран не идёт, только [isSecured].
  final String security;

  bool get isSecured => security.trim().isNotEmpty;

  @override
  String toString() =>
      'WifiNetwork(ssid: $ssid, signal: $signal%, '
      'secured: $isSecured)';
}
