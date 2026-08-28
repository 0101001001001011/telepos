import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';

class NetworkState {
  const NetworkState({
    this.loading = true,
    this.available = false,
    this.status,
    this.wifiNetworks = const [],
    this.bluetoothAvailable = true,
    this.bluetoothDevices = const [],
    this.scanningWifi = false,
    this.scanningBluetooth = false,
    this.busySsid,
    this.busyBtAddress,
    this.disconnecting = false,
    this.error,
  });

  final bool loading;

  final bool available;

  final NetworkStatus? status;

  final List<WifiNetwork> wifiNetworks;

  /// `false` в браузере — граница спеки 2026-08-24: Bluetooth не перенесён
  /// на провод. Экран обязан сказать об этом сразу, не дожидаясь неудачного
  /// нажатия «Поиск» (докстринг `NetworkRepository.bluetoothAvailable`).
  final bool bluetoothAvailable;

  final List<({String address, String name})> bluetoothDevices;

  final bool scanningWifi;
  final bool scanningBluetooth;

  final String? busySsid;

  final String? busyBtAddress;

  final bool disconnecting;

  final String? error;

  NetworkState copyWith({
    bool? loading,
    bool? available,
    NetworkStatus? status,
    List<WifiNetwork>? wifiNetworks,
    bool? bluetoothAvailable,
    List<({String address, String name})>? bluetoothDevices,
    bool? scanningWifi,
    bool? scanningBluetooth,
    String? busySsid,
    String? busyBtAddress,
    bool? disconnecting,
    String? error,
  }) {
    return NetworkState(
      loading: loading ?? this.loading,
      available: available ?? this.available,
      status: status ?? this.status,
      wifiNetworks: wifiNetworks ?? this.wifiNetworks,
      bluetoothAvailable: bluetoothAvailable ?? this.bluetoothAvailable,
      bluetoothDevices: bluetoothDevices ?? this.bluetoothDevices,
      scanningWifi: scanningWifi ?? this.scanningWifi,
      scanningBluetooth: scanningBluetooth ?? this.scanningBluetooth,
      busySsid: busySsid,
      busyBtAddress: busyBtAddress,
      disconnecting: disconnecting ?? this.disconnecting,
      error: error,
    );
  }
}

/// Задача «сетевые настройки по проводу» (спека 2026-08-24): контроллер
/// больше не строит `SysdClient` сам — берёт [NetworkRepository] через DI,
/// тем же приёмом, что `LoginNotifier` берёт `AuthRepository`
/// (`login_controller.dart`). Геттер, а не поле, заведённое в конструкторе:
/// провайдер может быть построен раньше, чем тест успевает подменить
/// регистрацию в `GetIt` (тот же довод, что у `LoginNotifier._auth`).
class NetworkNotifier extends Notifier<NetworkState> {
  NetworkRepository get _repo => GetIt.instance<NetworkRepository>();

  @override
  NetworkState build() {
    // Синхронно и один раз: экран обязан знать про Bluetooth сразу, не
    // дожидаясь нажатия «Поиск» — см. докстринг
    // `NetworkRepository.bluetoothAvailable`.
    return NetworkState(bluetoothAvailable: _repo.bluetoothAvailable);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final status = await _repo.status();
      state = state.copyWith(loading: false, available: true, status: status);
    } catch (_) {
      state = state.copyWith(loading: false, available: false);
    }
  }

  Future<void> refreshStatus() async {
    if (!state.available) return;
    try {
      final status = await _repo.status();
      state = state.copyWith(status: status, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> scanWifi() async {
    if (!state.available) return;
    state = state.copyWith(scanningWifi: true, error: null);
    try {
      final nets = await _repo.wifiScan();
      final sorted = [...nets]..sort((a, b) => b.signal.compareTo(a.signal));
      state = state.copyWith(scanningWifi: false, wifiNetworks: sorted);
    } catch (e) {
      state = state.copyWith(scanningWifi: false, error: e.toString());
    }
  }

  Future<({bool success, String message})> connectWifi(
    String ssid, [
    String? password,
  ]) async {
    state = state.copyWith(busySsid: ssid, error: null);
    try {
      final res = await _repo.wifiConnect(ssid, password);
      state = state.copyWith(busySsid: null);
      await refreshStatus();
      if (!res.success) {
        state = state.copyWith(error: res.message);
      }
      return res;
    } catch (e) {
      state = state.copyWith(busySsid: null, error: e.toString());
      return (success: false, message: e.toString());
    }
  }

  Future<void> disconnectWifi() async {
    state = state.copyWith(disconnecting: true, error: null);
    try {
      await _repo.wifiDisconnect();
      state = state.copyWith(disconnecting: false);
      await refreshStatus();
    } catch (e) {
      state = state.copyWith(disconnecting: false, error: e.toString());
    }
  }

  Future<({bool success, String message})> configureEthernetDhcp(
    String iface,
  ) async {
    try {
      final res = await _repo.ethernetConfigureDhcp(iface);
      await refreshStatus();
      return (success: res.success, message: '');
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return (success: false, message: e.toString());
    }
  }

  Future<({bool success, String message})> configureEthernetStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  }) async {
    try {
      final res = await _repo.ethernetConfigureStatic(
        iface,
        ipCidr: ipCidr,
        gateway: gateway,
        dns: dns,
      );
      await refreshStatus();
      return (success: res.success, message: '');
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return (success: false, message: e.toString());
    }
  }

  Future<Map<String, dynamic>?> ethernetDetails() async {
    if (!state.available) return null;
    try {
      return await _repo.ethernetStatus();
    } catch (_) {
      return null;
    }
  }

  Future<void> scanBluetooth() async {
    if (!state.available || !state.bluetoothAvailable) return;
    state = state.copyWith(scanningBluetooth: true, error: null);
    try {
      final devices = await _repo.bluetoothScan();
      state = state.copyWith(
        scanningBluetooth: false,
        bluetoothDevices: devices,
      );
    } catch (e) {
      state = state.copyWith(scanningBluetooth: false, error: e.toString());
    }
  }

  Future<({bool success, String message})> pairBluetooth(String address) async {
    if (!state.bluetoothAvailable) {
      return (success: false, message: '');
    }
    state = state.copyWith(busyBtAddress: address, error: null);
    try {
      final res = await _repo.bluetoothPair(address);
      state = state.copyWith(busyBtAddress: null);
      if (!res.success) {
        state = state.copyWith(error: res.message);
      }
      return res;
    } catch (e) {
      state = state.copyWith(busyBtAddress: null, error: e.toString());
      return (success: false, message: e.toString());
    }
  }
}

final networkControllerProvider =
    NotifierProvider<NetworkNotifier, NetworkState>(NetworkNotifier.new);
