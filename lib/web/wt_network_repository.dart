import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Сеть кассы — по проводу.
///
/// Шесть вопросов, все `Ask`: экран и так опрашивает состояние раз в четыре
/// секунды (`network_settings_screen.dart`), заводить ради него ещё и
/// подписку — лишний род обмена там, где хватает опроса (спека
/// 2026-08-24-network-settings-over-wire-design.md).
///
/// Отказы (нет демона на обычной Windows-кассе, к которой подключён браузер)
/// доезжают как есть — тем же `handler_failed`, каким становится любое
/// непойманное исключение на кассе (`till_wire.dart`, `_answer`), — а не
/// глотаются здесь: контроллер (`network_controller.dart`) ловит их тем же
/// `catch`, каким ловит и `SysdException` на десктопе, и показывает тот же
/// «недоступно», одинаково на обеих сборках.
class WtNetworkRepository implements NetworkRepository {
  const WtNetworkRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Future<NetworkStatus> status() => _wire.ask(TillOps.networkStatus, null);

  @override
  Future<List<WifiNetwork>> wifiScan() =>
      _wire.ask(TillOps.networkWifiScan, null);

  @override
  Future<({bool success, String message})> wifiConnect(
    String ssid, [
    String? password,
  ]) => _wire.ask(TillOps.networkWifiConnect, (ssid: ssid, password: password));

  @override
  Future<bool> wifiDisconnect() =>
      _wire.ask(TillOps.networkWifiDisconnect, null);

  @override
  Future<Map<String, dynamic>> ethernetStatus() =>
      _wire.ask(TillOps.networkEthernetStatus, null);

  @override
  Future<({bool success, String mode})> ethernetConfigureDhcp(String iface) =>
      _wire.ask(
        TillOps.networkEthernetConfigure,
        (iface: iface, mode: 'dhcp', ipCidr: null, gateway: null, dns: null),
      );

  @override
  Future<({bool success, String mode})> ethernetConfigureStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  }) => _wire.ask(
    TillOps.networkEthernetConfigure,
    (iface: iface, mode: 'static', ipCidr: ipCidr, gateway: gateway, dns: dns),
  );

  /// Граница спеки 2026-08-24: Bluetooth не переносится на провод — см.
  /// докстринг `NetworkRepository`.
  @override
  bool get bluetoothAvailable => false;

  /// Не вызывается контроллером, когда [bluetoothAvailable] — `false`
  /// (`NetworkController.build`) — но реализация обязана существовать и
  /// обязана отказать честно, а не изобразить пустой список, если её всё же
  /// позвали.
  @override
  Future<List<({String address, String name})>> bluetoothScan() async {
    throw UnsupportedError(
      'Bluetooth не перенесён на провод — граница спеки '
      '2026-08-24-network-settings-over-wire-design.md',
    );
  }

  @override
  Future<({bool success, String message})> bluetoothPair(String address) async {
    throw UnsupportedError(
      'Bluetooth не перенесён на провод — граница спеки '
      '2026-08-24-network-settings-over-wire-design.md',
    );
  }
}
