/// Сеть кассы — статус, Wi-Fi, Ethernet — за одним контрактом, двумя
/// реализациями: `NetworkRepositoryLocal` (`lib/data/network/`) говорит с
/// `telepos-sysd` напрямую по юникс-сокету, `WtNetworkRepository`
/// (`lib/web/`) — тем же шестью вопросами по проводу. Тот же приём, что уже
/// обкатан `DeviceDiscovery`/`DeviceCheck` (план 2b, задача 3) и
/// `TerminalRepository` — контракт в домене, две реализации, переключение в
/// DI (`service_locator.dart` на кассе, `main_web.dart` в браузере).
///
/// Спека `docs/internal/superpowers/specs/2026-08-24-network-settings-over-wire-design.md`.
///
/// # Экран настраивает сеть кассы, не терминала
///
/// Юникс-сокет `telepos-sysd` всегда локален для того процесса, который его
/// открыл. Что бы ни спрашивал браузер, ответ — про сеть **кассы**, к которой
/// он подключён, а не про сеть планшета, на котором открыта вкладка.
///
/// # Демон есть только на приборных сборках
///
/// Обычная Windows-касса без `telepos-sysd` отвечает отказом на каждый метод
/// ниже — так же честно на кассе и в браузере (граница спеки, пункт
/// «Проверка», №4). `NetworkRepositoryLocal` не глотает эту причину: она
/// доезжает до вызывающего кода как исключение, а не как молчаливая пустота.
///
/// # Bluetooth и точка доступа — граница, а не забывчивость
///
/// Экран показывает карточку Bluetooth и на кассе, и в браузере, но эта
/// работа не заводит для него операции провода: демон умеет
/// `hardware.bluetooth_scan`/`hardware.bluetooth_pair`
/// (`SysdClient.bluetoothScan`/`bluetoothPair`), и касса продолжает
/// говорить с ним напрямую (`NetworkRepositoryLocal`) — но перенос самого
/// обмена на провод ничего не добавляет к проверке архитектуры, ради которой
/// работа берётся (спека, раздел «Границы»). [bluetoothAvailable] — то, чем
/// экран узнаёт об этом заранее, не дожидаясь нажатия «Поиск»:
/// `WtNetworkRepository.bluetoothAvailable` — всегда `false`, а
/// [bluetoothScan]/[bluetoothPair] там не вызываются вовсе (см. докстринг
/// класса).
///
/// Точка доступа (`network.ap_start`/`ap_stop`/`ap_clients` в
/// `telepos-os/sysd/src/network.rs`) в этом контракте не появляется вовсе —
/// ни этот экран, ни `SysdClient` её никогда не оборачивали, переносить
/// здесь нечего.
library;

import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';

abstract interface class NetworkRepository {
  /// Состояние сети: подключён ли Wi-Fi, к какой сети, есть ли кабель, есть
  /// ли интернет.
  Future<NetworkStatus> status();

  /// Сети, видимые прямо сейчас. Экран зовёт по нажатию «Поиск», не сам —
  /// как и `DeviceDiscovery.find`: перечисление — работа по кнопке, а не
  /// состояние, за которым следят.
  Future<List<WifiNetwork>> wifiScan();

  /// Подключиться к сети. `password` — `null`/пусто для открытой сети.
  Future<({bool success, String message})> wifiConnect(
    String ssid, [
    String? password,
  ]);

  /// Отключиться от текущей сети Wi-Fi.
  Future<bool> wifiDisconnect();

  /// Подробности проводного интерфейса — адреса, режим. Форма варьируется по
  /// тому, что вернул `ip -j addr show` на кассе, поэтому едет как есть, без
  /// собственной модели: единственный сегодняшний читатель
  /// (`_EthernetConfigDialog._loadDetails`) уже разбирает её терпимо, тем же
  /// приёмом, каким жил до переноса на провод.
  Future<Map<String, dynamic>> ethernetStatus();

  /// Настроить проводной интерфейс на DHCP.
  Future<({bool success, String mode})> ethernetConfigureDhcp(String iface);

  /// Настроить проводной интерфейс статическим адресом.
  Future<({bool success, String mode})> ethernetConfigureStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  });

  /// `true` — эта реализация умеет говорить с Bluetooth демона.
  /// `NetworkRepositoryLocal` — всегда `true` (кассе есть с кем говорить, даже
  /// если сам демон сейчас недоступен — недоступность демона [status] и
  /// прочие методы обязаны назвать сами, как и всегда). `WtNetworkRepository`
  /// — всегда `false`: граница спеки 2026-08-24, см. докстринг класса.
  ///
  /// Читается синхронно и один раз при построении контроллера — экран
  /// обязан сказать про Bluetooth сразу, не дожидаясь неудачного нажатия
  /// «Поиск» (спека, раздел «Границы»: «останутся заглушкой в браузере —
  /// назвать на экране, а не молчать»).
  bool get bluetoothAvailable;

  /// Спаренные и обнаруженные Bluetooth-устройства. Не вызывается, когда
  /// [bluetoothAvailable] — `false`: `WtNetworkRepository` бросает
  /// `UnsupportedError` вместо связи с проводом — операции для этого
  /// сознательно не заведено (см. докстринг класса).
  Future<List<({String address, String name})>> bluetoothScan();

  /// Сопряжение с устройством по адресу. Тот же запрет вызова при
  /// `!bluetoothAvailable`, что и у [bluetoothScan].
  Future<({bool success, String message})> bluetoothPair(String address);
}
