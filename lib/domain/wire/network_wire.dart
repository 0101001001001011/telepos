/// Форма `NetworkStatus`/`WifiNetwork` на проводе — тем же приёмом, что
/// `device_wire.dart` уже даёт `DeviceCandidate`/`DeviceCheckOutcome`: один
/// кодировщик, которым пользуется и касса (`till_operations.dart`), и
/// каталог операций (`till_ops.dart`) на разборе ответа.
library;

import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';

Map<String, Object?> networkStatusToWireJson(NetworkStatus status) => {
  'wifiConnected': status.wifiConnected,
  'wifiSsid': status.wifiSsid,
  'wifiSignal': status.wifiSignal,
  'ethernetConnected': status.ethernetConnected,
  'ethernetInterface': status.ethernetInterface,
  'internet': status.internet,
};

NetworkStatus networkStatusFromWireJson(Map<String, dynamic> json) =>
    NetworkStatus(
      wifiConnected: json['wifiConnected'] as bool? ?? false,
      wifiSsid: json['wifiSsid'] as String?,
      wifiSignal: (json['wifiSignal'] as num?)?.toInt(),
      ethernetConnected: json['ethernetConnected'] as bool? ?? false,
      ethernetInterface: json['ethernetInterface'] as String?,
      internet: json['internet'] as bool? ?? false,
    );

Map<String, Object?> wifiNetworkToWireJson(WifiNetwork network) => {
  'ssid': network.ssid,
  'signal': network.signal,
  'security': network.security,
};

WifiNetwork wifiNetworkFromWireJson(Map<String, dynamic> json) => WifiNetwork(
  ssid: json['ssid'] as String? ?? '',
  signal: (json['signal'] as num?)?.toInt() ?? 0,
  security: json['security'] as String? ?? '',
);
