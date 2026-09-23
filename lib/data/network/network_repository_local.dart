import 'package:telepos/data/sysd/sysd_client.dart' as sysd;
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';

/// Реализация [NetworkRepository] на кассе — тонкая обёртка над
/// `SysdClient`, тем же приёмом, что `DeviceDiscoveryLocal`/
/// `DeviceCheckLocal` (`lib/data/device/`). Ничего не решает сама:
/// недостижимость демона (обычная Windows-касса без `telepos-sysd`) — это
/// `SysdException`, которую `SysdClient` уже бросает, а этот класс не
/// глотает: экран узнаёт причину, а не тишину, — и это одинаково на кассе и
/// в браузере, потому что упавший обработчик `network.*` на кассе становится
/// `ErrorFrame('handler_failed', …)` (`till_wire.dart`) —
/// `WtNetworkRepository` получает тот же отказ, что и десктопный вызывающий
/// код здесь, только по проводу.
///
/// Импорт `SysdClient` — под псевдонимом `sysd`: и оно, и
/// `NetworkRepository` называют `NetworkStatus`/`WifiNetwork` — разные типы
/// в разных слоях с одинаковыми именами (докстринг
/// `lib/domain/network/network_status.dart`), и без псевдонима импорт
/// неоднозначен.
class NetworkRepositoryLocal implements NetworkRepository {
  NetworkRepositoryLocal({sysd.SysdClient? client})
    : _sysd = client ?? sysd.SysdClient();

  final sysd.SysdClient _sysd;

  @override
  bool get bluetoothAvailable => true;

  @override
  Future<NetworkStatus> status() async {
    final s = await _sysd.networkStatus();
    return NetworkStatus(
      wifiConnected: s.wifiConnected,
      wifiSsid: s.wifiSsid,
      wifiSignal: s.wifiSignal,
      ethernetConnected: s.ethernetConnected,
      ethernetInterface: s.ethernetInterface,
      internet: s.internet,
    );
  }

  @override
  Future<List<WifiNetwork>> wifiScan() async {
    final nets = await _sysd.wifiScan();
    return nets
        .map(
          (n) =>
              WifiNetwork(ssid: n.ssid, signal: n.signal, security: n.security),
        )
        .toList();
  }

  @override
  Future<({bool success, String message})> wifiConnect(
    String ssid, [
    String? password,
  ]) => _sysd.wifiConnect(ssid, password);

  @override
  Future<bool> wifiDisconnect() => _sysd.wifiDisconnect();

  @override
  Future<Map<String, dynamic>> ethernetStatus() => _sysd.ethernetStatus();

  @override
  Future<({bool success, String mode})> ethernetConfigureDhcp(String iface) =>
      _sysd.ethernetConfigureDhcp(iface);

  @override
  Future<({bool success, String mode})> ethernetConfigureStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  }) => _sysd.ethernetConfigureStatic(
    iface,
    ipCidr: ipCidr,
    gateway: gateway,
    dns: dns,
  );

  @override
  Future<List<({String address, String name})>> bluetoothScan() async {
    final devices = await _sysd.bluetoothScan();
    return devices.map((d) => (address: d.address, name: d.name)).toList();
  }

  @override
  Future<({bool success, String message})> bluetoothPair(String address) =>
      _sysd.bluetoothPair(address);
}
