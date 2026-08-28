import 'package:meta/meta.dart';

/// Что умеет машина, на которой мы запущены.
///
/// Экраны спрашивают возможность, а не роль: «кто-то здесь управляет сетью?»
/// вместо «я киоск?». Иначе появление пятого облика означает правку каждого
/// `switch` в программе, и один из них забудут. См. docs/system-architecture.md,
/// раздел 4 и И9.
@immutable
class HostCapabilities {
  const HostCapabilities({
    required this.managesNetwork,
    required this.canInstallDrivers,
    required this.controlsDisplay,
    required this.managesTime,
    required this.ownsDevices,
    required this.ownsData,
    required this.servesTerminals,
  });

  /// Сеть настраивается здесь, а не в операционной системе клиента.
  final bool managesNetwork;

  /// Есть каталог пакетов и право их устанавливать.
  final bool canInstallDrivers;

  /// Яркость и поворот экрана в нашей власти.
  final bool controlsDisplay;

  /// Источник времени и NTP в нашей власти.
  final bool managesTime;

  /// Устройства подключены к этой машине физически.
  final bool ownsDevices;

  /// База данных живёт здесь.
  final bool ownsData;

  /// Раздаёт API другим терминалам.
  final bool servesTerminals;

  /// Браузерная вкладка. Ничем не владеет; устройства настраивает у кассы,
  /// к которой подключена.
  static const browser = HostCapabilities(
    managesNetwork: false,
    canInstallDrivers: false,
    controlsDisplay: false,
    managesTime: false,
    ownsDevices: false,
    ownsData: false,
    servesTerminals: false,
  );

  /// Обычное приложение на Windows, macOS или Linux. Сеть и время — забота ОС
  /// клиента.
  static const desktop = HostCapabilities(
    managesNetwork: false,
    canInstallDrivers: false,
    controlsDisplay: false,
    managesTime: false,
    ownsDevices: true,
    ownsData: true,
    servesTerminals: true,
  );

  /// Наш образ. Владеет машиной целиком через telepos-sysd.
  static const appliance = HostCapabilities(
    managesNetwork: true,
    canInstallDrivers: true,
    controlsDisplay: true,
    managesTime: true,
    ownsDevices: true,
    ownsData: true,
    servesTerminals: true,
  );

  /// Серверная роль: данные есть, устройств нет.
  static const server = HostCapabilities(
    managesNetwork: false,
    canInstallDrivers: false,
    controlsDisplay: false,
    managesTime: false,
    ownsDevices: false,
    ownsData: true,
    servesTerminals: true,
  );
}
