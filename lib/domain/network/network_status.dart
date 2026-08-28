import 'package:meta/meta.dart';

/// Состояние сети кассы — Wi-Fi, Ethernet, интернет — как их видит демон
/// `telepos-sysd` (`D:\Projects\NOVA\telepos-os\sysd\src\network.rs`,
/// `network.status`).
///
/// Раньше жил в `lib/data/sysd/sysd_client.dart` — слое данных. Кодировщик
/// провода (`lib/domain/wire/network_wire.dart`) обязан работать с доменным
/// типом, а не тянуть `lib/data/`, поэтому задача «сетевые настройки по
/// проводу» (спека 2026-08-24) переносит его сюда без изменения полей —
/// перенос, а не переделка.
@immutable
class NetworkStatus {
  const NetworkStatus({
    required this.wifiConnected,
    required this.wifiSsid,
    required this.wifiSignal,
    required this.ethernetConnected,
    required this.ethernetInterface,
    required this.internet,
  });

  final bool wifiConnected;
  final String? wifiSsid;
  final int? wifiSignal;
  final bool ethernetConnected;
  final String? ethernetInterface;
  final bool internet;

  @override
  String toString() =>
      'NetworkStatus(wifi: $wifiConnected/$wifiSsid, '
      'ethernet: $ethernetConnected/$ethernetInterface, internet: $internet)';
}
