import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// Narrow view of the character device a printer sits behind — `/dev/usb/lp0`
/// or a serial port.
///
/// Both wires answer the same three questions, and the answer to the middle one
/// is what the whole write policy turns on: **how many bytes did the device
/// accept?** A count that is short of what was offered is decidable — the rest
/// was not written, and writing the rest completes the same stream. An
/// exception is not decidable: the bytes may already be paper.
///
/// The seam exists because the real devices are `dart:io` file handles and FFI
/// serial ports; without it the policy above cannot be tested at all.
abstract class PrinterCharDevice {
  bool get isOpen;

  /// Hands [data] to the device and returns how many bytes it accepted.
  /// Fewer than `data.length` means a short write: the remainder was **not**
  /// written. Throwing means the outcome is unknown.
  int write(Uint8List data);

  void flush();

  void close();
}

/// Opens [path], or throws when it cannot be opened.
typedef PrinterCharDeviceOpener = PrinterCharDevice Function(String path);

/// Lists the character-device nodes a receipt printer could be behind.
typedef PrinterNodeLister = List<String> Function();

class _RawNodeDevice implements PrinterCharDevice {
  _RawNodeDevice(this._file);

  final RandomAccessFile _file;
  bool _open = true;

  @override
  bool get isOpen => _open;

  @override
  int write(Uint8List data) {
    // `writeFromSync` writes everything or throws; it never reports a partial
    // count. That is precisely why a failed write on this wire cannot be
    // retried — see `LinuxPrinterManager.writeRaw`.
    _file.writeFromSync(data);
    return data.length;
  }

  @override
  void flush() => _file.flushSync();

  @override
  void close() {
    _open = false;
    try {
      _file.flushSync();
    } catch (_) {}
    try {
      _file.closeSync();
    } catch (_) {}
  }
}

class _SerialPortDevice implements PrinterCharDevice {
  _SerialPortDevice(this._port);

  final SerialPort _port;

  @override
  bool get isOpen {
    try {
      return _port.isOpen;
    } catch (_) {
      return false;
    }
  }

  @override
  int write(Uint8List data) {
    final written = _port.write(data);
    if (written < 0) {
      throw Exception(SerialPort.lastError?.message ?? 'Write returned $written');
    }
    return written;
  }

  @override
  void flush() {
    try {
      _port.flush();
    } catch (_) {}
  }

  @override
  void close() {
    try {
      if (_port.isOpen) _port.close();
    } catch (_) {}
    try {
      _port.dispose();
    } catch (_) {}
  }
}

class LinuxPrinterManager extends BufferedPrinterManager {
  LinuxPrinterManager({
    String? devicePath,
    int? baudRate,
    PrinterCharDeviceOpener? deviceOpener,
    PrinterNodeLister? nodeLister,
    bool Function(String path)? nodeExists,
    int? maxOpenAttempts,
    Duration? reopenDelay,
    Duration? retryBudget,
  }) : _devicePath = devicePath ?? defaultDevicePath,
       baudRate = baudRate ?? defaultBaudRate,
       _deviceOpener = deviceOpener ?? _openRawNode,
       _nodeLister = nodeLister,
       _nodeExists = nodeExists ?? _isUsableNode,
       maxOpenAttempts = maxOpenAttempts ?? defaultMaxOpenAttempts,
       reopenDelay =
           reopenDelay ?? const Duration(milliseconds: reopenDelayMs),
       retryBudget = retryBudget ?? const Duration(milliseconds: retryBudgetMs);

  static const String defaultDevicePath = '/dev/usb/lp0';

  static const List<String> alternativeDevicePaths = [
    '/dev/usb/lp0',
    '/dev/usb/lp1',
    '/dev/ttyUSB0',
    '/dev/ttyUSB1',
    '/dev/ttyACM0',
  ];

  static const int defaultBaudRate = 9600;

  /// Attempts at **opening** the device, and the pause between them.
  ///
  /// Opening is the only thing worth retrying on this wire: an open that failed
  /// has printed nothing. The count keeps the previous behaviour — the old loop
  /// ran `attempt = 0; attempt <= 6`, which is seven attempts, not six — and the
  /// 400 ms pause is unchanged, because a printer that was replugged comes back
  /// on that scale.
  static const int defaultMaxOpenAttempts = 7;

  static const int reopenDelayMs = 400;

  /// Wall-clock ceiling for one [writeRaw], covering every open attempt, every
  /// pause and the write itself (И30: a retry loop must not stall its caller).
  /// Seven attempts at 400 ms fit inside it; the budget is what stops the
  /// sequence if an open itself hangs.
  static const int retryBudgetMs = 3000;

  final String _devicePath;

  /// The device node this manager was bound to, before any auto-detection.
  ///
  /// Public for exactly the reason `WindowsPrinterManager.portName` is public:
  /// the end-to-end test that proves a USB binding chosen in the setup wizard
  /// reaches a real driver has to read back the path it bound. On Windows it
  /// could; on Linux it could not, so the assertion was written against
  /// Windows only and the whole suite became platform-locked with it
  /// (CI run 30679639760).
  String get devicePath => _devicePath;

  final PrinterCharDeviceOpener _deviceOpener;
  final PrinterNodeLister? _nodeLister;
  final bool Function(String path) _nodeExists;

  final int baudRate;

  final int maxOpenAttempts;

  final Duration reopenDelay;

  final Duration retryBudget;

  bool _isConnected = false;
  PrinterInfo? _printerInfo;

  PrinterCharDevice? _device;
  String? _openPath;
  bool _deviceIsRawNode = false;

  String? _rawOpenHint;

  static bool _isRawPath(String p) => RegExp(r'lp[0-9]+$').hasMatch(p);

  static PrinterCharDevice _openRawNode(String path) =>
      _RawNodeDevice(File(path).openSync(mode: FileMode.writeOnlyAppend));

  List<String> get _rawCandidates {
    final lister = _nodeLister;
    if (lister != null) return lister();

    final found = <String>{};
    if (_isRawPath(_devicePath) && _isUsableNode(_devicePath)) {
      found.add(_devicePath);
    }
    for (final dir in const ['/dev/usb', '/dev']) {
      try {
        for (final e in Directory(dir).listSync(followLinks: false)) {
          if (!_isRawPath(e.path)) continue;
          if (FileSystemEntity.typeSync(e.path) == FileSystemEntityType.file) {
            continue;
          }
          found.add(e.path);
        }
      } catch (_) {}
    }
    return found.toList()..sort();
  }

  static bool _isUsableNode(String path) {
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.file) {
      return false;
    }
    final i = path.lastIndexOf('/');
    if (i <= 0) return false;
    try {
      for (final e in Directory(
        path.substring(0, i),
      ).listSync(followLinks: false)) {
        if (e.path == path) return true;
      }
    } catch (_) {}
    return false;
  }

  bool _openRawDevice() {
    _rawOpenHint = null;
    for (final path in _rawCandidates) {
      try {
        _device = _deviceOpener(path);
        _openPath = path;
        _deviceIsRawNode = true;
        _isConnected = true;
        _printerInfo = PrinterInfo(
          name: 'USB Printer (raw)',
          address: path,
          model: 'ESC/POS',
          paperWidth: 58,
        );
        return true;
      } catch (e) {
        _device = null;
        _openPath = null;
        _rawOpenHint =
            'Узел $path найден, но открыть нельзя — нет прав. '
            'Добавьте пользователя в группу lp (usermod -aG lp telepos) и '
            'перезапустите сессию/приставку.';
      }
    }
    return false;
  }

  void _closeDevice() {
    try {
      _device?.close();
    } catch (_) {}
    _device = null;
    _openPath = null;
    _deviceIsRawNode = false;
  }

  @override
  bool get isConnected => _isConnected;

  @override
  Future<PrinterAutoDetectResult> autoDetect() async {
    for (final path in _rawCandidates) {
      bool openable;
      try {
        _deviceOpener(path).close();
        openable = true;
      } catch (_) {
        openable = false;
      }
      return PrinterAutoDetectResult(
        found: true,
        connectionType: 'usb',
        address: path,
        label: 'USB-принтер ($path)',
        note: openable
            ? null
            : 'Узел найден, но нет прав (нужна группа lp): '
                  'usermod -aG lp telepos + перезапуск сессии.',
      );
    }
    try {
      for (final p in SerialPort.availablePorts) {
        if (p.contains('ttyUSB') || p.contains('ttyACM')) {
          return PrinterAutoDetectResult(
            found: true,
            connectionType: 'serial',
            address: p,
            label: 'Serial-принтер ($p)',
          );
        }
      }
    } catch (_) {}
    return const PrinterAutoDetectResult(found: false);
  }

  @override
  Future<PrinterConnectionResult> connect() async {
    if (_openRawDevice()) {
      return PrinterConnectionResult.ok(_printerInfo!);
    }

    try {
      final devicePath = _findAvailableDevice();
      if (devicePath == null) {
        return PrinterConnectionResult.error(
          _rawOpenHint ??
              'Принтер не найден: нет ни одного char-узла /dev/usb/lp* и '
                  'USB-serial порта. Проверьте кабель и питание принтера.',
        );
      }

      final port = SerialPort(devicePath);

      if (!port.openReadWrite()) {
        final err = SerialPort.lastError?.message ?? 'Unknown error';
        port.dispose();
        return PrinterConnectionResult.error(
          'Не удалось открыть устройство $devicePath: $err',
        );
      }

      final config = port.config;
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      port.config = config;

      _device = _SerialPortDevice(port);
      _openPath = devicePath;
      _deviceIsRawNode = false;
      _isConnected = true;
      _printerInfo = PrinterInfo(
        name: 'Linux Serial Printer',
        address: devicePath,
        model: 'ESC/POS',
        paperWidth: 58,
      );

      return PrinterConnectionResult.ok(_printerInfo!);
    } catch (e) {
      _closeDevice();
      return PrinterConnectionResult.error('Ошибка подключения: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _closeDevice();
    _isConnected = false;
    _printerInfo = null;
  }

  @override
  Future<PrinterStatus> getStatus() async {
    final device = _device;
    if (!_isConnected || device == null || !device.isOpen) {
      _isConnected = false;
      return PrinterStatus.offline;
    }

    final path = _openPath;
    if (_deviceIsRawNode && path != null && !_nodeExists(path)) {
      _closeDevice();
      _isConnected = false;
      return PrinterStatus.offline;
    }

    return PrinterStatus.ok;
  }

  /// Hands [data] to the device **at most once**.
  ///
  /// ## What is decidable on this wire, and what is not
  ///
  /// *Opening* is decidable: an open that failed printed nothing, so it may be
  /// retried as often as [maxOpenAttempts] and [retryBudget] allow. That is the
  /// only retry left here.
  ///
  /// A *short write* is decidable, and only on the serial path: `SerialPort.write`
  /// returns how many bytes were accepted, so the device consumed exactly that
  /// many and the remainder was not written. Writing the remainder is a
  /// **continuation of the same stream**, not a re-send — nothing is printed
  /// twice by it. That is why the loop below advances by the accepted count
  /// instead of offering the whole payload again.
  ///
  /// A *failed write* is **not** decidable on either path. `writeFromSync` on a
  /// raw node writes everything or throws and never reports how far it got, and
  /// a serial write that throws is in the same position. The bytes may already
  /// be on paper, and no journal above this line can recall them. So a write
  /// that threw is reported, never repeated: the previous code reopened the node
  /// and sent the whole payload again, up to seven times, which prints the tail
  /// of a receipt and then a whole one.
  ///
  /// Repeating whole *jobs* is the queue's business, because that is where the
  /// idempotency key lives (И29).
  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    final deadline = DateTime.now().add(retryBudget);

    // Phase 1: get a device. Nothing has been committed yet, so this may retry.
    for (var attempt = 1; _device == null; attempt++) {
      final connection = await connect();
      if (connection.success) break;

      // Retrying is for a node that exists but cannot be opened right now — a
      // printer that is busy or was just replugged. When no node exists at all
      // there is nothing to come back to, and seven 400 ms waits only delay the
      // sale.
      final nothingToWaitFor = _rawCandidates.isEmpty;
      if (nothingToWaitFor ||
          attempt >= maxOpenAttempts ||
          _remaining(deadline) <= Duration.zero) {
        _isConnected = false;
        return PrintResult.error(
          'Печать не удалась — принтер недоступен '
          '(попыток открыть: $attempt из $maxOpenAttempts); ничего не '
          'отправлено: ${connection.errorMessage}',
        );
      }

      final left = _remaining(deadline);
      await Future<void>.delayed(left < reopenDelay ? left : reopenDelay);
    }

    final device = _device!;

    // Phase 2: hand the payload over. Exactly once.
    var sent = 0;
    try {
      while (sent < data.length) {
        final chunk = sent == 0
            ? data
            : Uint8List.sublistView(data, sent, data.length);
        final accepted = device.write(chunk);
        if (accepted <= 0) {
          throw Exception(
            'устройство не приняло ни одного байта из ${chunk.length}',
          );
        }
        sent += accepted;

        if (sent < data.length && _remaining(deadline) <= Duration.zero) {
          throw Exception(
            'срок ${retryBudget.inMilliseconds} мс истёк на середине записи',
          );
        }
      }
      device.flush();
      return PrintResult.ok(bytesSent: sent);
    } catch (e) {
      // Часть данных могла уже стать бумагой, и сколько именно — этот провод не
      // сообщает. Поэтому запись объявляется неподтверждённой и не повторяется.
      _closeDevice();
      _isConnected = false;
      return PrintResult.error(
        'Печать на ${_printerInfo?.address ?? _devicePath} не подтверждена — '
        'устройство подтвердило $sent из ${data.length} байт, часть остальных '
        'могла уже стать бумагой: $e. Повторяет задание очередь, транспорт тот '
        'же чек второй раз не отправляет',
      );
    }
  }

  Duration _remaining(DateTime deadline) => deadline.difference(DateTime.now());

  String? _findAvailableDevice() {
    try {
      final availablePorts = SerialPort.availablePorts;

      if (availablePorts.contains(_devicePath)) {
        return _devicePath;
      }

      for (final path in alternativeDevicePaths) {
        if (availablePorts.contains(path)) {
          return path;
        }
      }

      for (final port in availablePorts) {
        if (port.contains('ttyUSB') ||
            port.contains('ttyACM') ||
            port.contains('usb/lp')) {
          return port;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

class LinuxPrinterScanner {
  LinuxPrinterScanner._();

  static Future<List<LinuxPrinterInfo>> scanDevices() async {
    try {
      final portNames = SerialPort.availablePorts;
      final devices = <LinuxPrinterInfo>[];

      for (final portName in portNames) {
        try {
          final port = SerialPort(portName);
          devices.add(
            LinuxPrinterInfo(
              devicePath: portName,
              description: port.description ?? portName,
              vendorId: port.vendorId,
              productId: port.productId,
              serialNumber: port.serialNumber,
            ),
          );
          port.dispose();
        } catch (_) {
          devices.add(
            LinuxPrinterInfo(devicePath: portName, description: portName),
          );
        }
      }

      final lpRe = RegExp(r'lp[0-9]+$');
      final lpSeen = <String>{};
      for (final dir in const ['/dev/usb', '/dev']) {
        try {
          for (final e in Directory(dir).listSync(followLinks: false)) {
            final p = e.path;
            if (!lpRe.hasMatch(p) || lpSeen.contains(p)) continue;
            if (FileSystemEntity.typeSync(p) == FileSystemEntityType.file) {
              continue;
            }
            lpSeen.add(p);
            devices.add(
              LinuxPrinterInfo(
                devicePath: p,
                description: 'USB receipt printer ($p)',
              ),
            );
          }
        } catch (_) {}
      }

      return devices;
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> getSerialPorts() async {
    try {
      return SerialPort.availablePorts;
    } catch (_) {
      return [];
    }
  }
}

class LinuxPrinterInfo {
  const LinuxPrinterInfo({
    required this.devicePath,
    required this.description,
    this.vendorId,
    this.productId,
    this.serialNumber,
  });

  final String devicePath;

  final String description;

  final int? vendorId;

  final int? productId;

  final String? serialNumber;

  String get vidPid {
    if (vendorId == null || productId == null) return '';
    return '${vendorId!.toRadixString(16).padLeft(4, '0')}:'
        '${productId!.toRadixString(16).padLeft(4, '0')}';
  }

  @override
  String toString() => 'LinuxPrinterInfo($devicePath - $description)';
}
