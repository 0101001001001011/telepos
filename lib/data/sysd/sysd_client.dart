import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SysdException implements Exception {
  SysdException(this.message);
  final String message;
  @override
  String toString() => 'SysdException: $message';
}

class SessionStatus {
  const SessionStatus({
    required this.current,
    required this.kioskActive,
    required this.desktopActive,
  });

  final String current;
  final bool kioskActive;
  final bool desktopActive;

  factory SessionStatus.fromJson(Map<String, dynamic> j) => SessionStatus(
    current: (j['current'] ?? 'none') as String,
    kioskActive: (j['kiosk_active'] ?? false) as bool,
    desktopActive: (j['desktop_active'] ?? false) as bool,
  );
}

class DriverItem {
  const DriverItem({
    required this.id,
    required this.title,
    required this.category,
    required this.installed,
    required this.packages,
  });

  final String id;
  final String title;
  final String category;
  final bool installed;
  final List<String> packages;

  factory DriverItem.fromJson(Map<String, dynamic> j) => DriverItem(
    id: (j['id'] ?? '') as String,
    title: (j['title'] ?? j['id'] ?? '') as String,
    category: (j['category'] ?? '') as String,
    installed: (j['installed'] ?? false) as bool,
    packages: ((j['packages'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

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

  factory NetworkStatus.fromJson(Map<String, dynamic> j) {
    final wifi = (j['wifi'] as Map?)?.cast<String, dynamic>() ?? const {};
    final eth = (j['ethernet'] as Map?)?.cast<String, dynamic>() ?? const {};
    final iface =
        (eth['interface'] ?? eth['iface'] ?? eth['device']) as String?;
    return NetworkStatus(
      wifiConnected: (wifi['connected'] ?? false) as bool,
      wifiSsid: wifi['ssid'] as String?,
      wifiSignal: (wifi['signal'] as num?)?.toInt(),
      ethernetConnected: (eth['connected'] ?? false) as bool,
      ethernetInterface: (iface != null && iface.trim().isNotEmpty)
          ? iface
          : null,
      internet: (j['internet'] ?? false) as bool,
    );
  }
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.security,
  });

  final String ssid;
  final int signal;

  final String security;

  bool get isSecured => security.trim().isNotEmpty;

  factory WifiNetwork.fromJson(Map<String, dynamic> j) => WifiNetwork(
    ssid: (j['ssid'] ?? '') as String,
    signal: (j['signal'] as num?)?.toInt() ?? 0,
    security: (j['security'] ?? '') as String,
  );
}

class ExecResult {
  const ExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;

  bool get ok => exitCode == 0;

  factory ExecResult.fromJson(Map<String, dynamic> j) => ExecResult(
    stdout: (j['stdout'] ?? '') as String,
    stderr: (j['stderr'] ?? '') as String,
    exitCode: (j['exit_code'] as num?)?.toInt() ?? 0,
  );
}

class SystemTime {
  const SystemTime({
    required this.time,
    required this.timezone,
    this.ntpSynchronized,
  });

  final String time;

  final String timezone;

  final bool? ntpSynchronized;

  factory SystemTime.fromJson(Map<String, dynamic> j) {
    String tz = (j['timezone'] ?? j['tz'] ?? j['Timezone'] ?? '') as String;

    String time =
        (j['time'] ?? j['local_time'] ?? j['datetime'] ?? '') as String;
    if (time.isEmpty) {
      final usec = j['TimeUSec'] ?? j['timestamp_usec'];
      final micros = usec is num
          ? usec.toInt()
          : int.tryParse(
              usec?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
            );
      if (micros != null && micros > 0) {
        final dt = DateTime.fromMicrosecondsSinceEpoch(micros).toLocal();
        time =
            '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}:'
            '${dt.second.toString().padLeft(2, '0')}';
      }
    }

    bool? ntp = j['ntp_synchronized'] as bool? ?? j['ntp_sync'] as bool?;
    if (ntp == null) {
      final raw = (j['NTPSynchronized'] ?? j['ntp']);
      if (raw is bool) {
        ntp = raw;
      } else if (raw != null) {
        final s = raw.toString().toLowerCase();
        ntp = s == 'yes' || s == 'true' || s == '1';
      }
    }

    return SystemTime(time: time, timezone: tz, ntpSynchronized: ntp);
  }
}

class NtpSyncResult {
  const NtpSyncResult({
    required this.success,
    required this.tracking,
    required this.time,
    required this.message,
  });

  final bool success;
  final String tracking;
  final String time;
  final String message;

  factory NtpSyncResult.fromJson(Map<String, dynamic> j) => NtpSyncResult(
    success: (j['success'] ?? false) as bool,
    tracking: (j['tracking'] ?? '') as String,
    time: (j['time'] ?? '') as String,
    message: (j['message'] ?? '') as String,
  );
}

class SystemHealth {
  const SystemHealth({
    required this.cpuPercent,
    required this.cpuCores,
    required this.memoryTotalMb,
    required this.memoryUsedMb,
    required this.memoryPercent,
    required this.diskTotalGb,
    required this.diskAvailableGb,
    required this.temperatureC,
    required this.uptimeSecs,
  });

  final double cpuPercent;
  final int cpuCores;
  final int memoryTotalMb;
  final int memoryUsedMb;
  final double memoryPercent;
  final double diskTotalGb;
  final double diskAvailableGb;
  final double? temperatureC;
  final int uptimeSecs;

  factory SystemHealth.fromJson(Map<String, dynamic> j) {
    final cpu = (j['cpu'] as Map?)?.cast<String, dynamic>() ?? const {};
    final mem = (j['memory'] as Map?)?.cast<String, dynamic>() ?? const {};
    final disk = (j['disk'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SystemHealth(
      cpuPercent: (cpu['usage_percent'] as num?)?.toDouble() ?? 0,
      cpuCores: (cpu['cores'] as num?)?.toInt() ?? 0,
      memoryTotalMb: (mem['total_mb'] as num?)?.toInt() ?? 0,
      memoryUsedMb: (mem['used_mb'] as num?)?.toInt() ?? 0,
      memoryPercent: (mem['percent'] as num?)?.toDouble() ?? 0,
      diskTotalGb: (disk['total_gb'] as num?)?.toDouble() ?? 0,
      diskAvailableGb: (disk['available_gb'] as num?)?.toDouble() ?? 0,
      temperatureC: (j['temperature_c'] as num?)?.toDouble(),
      uptimeSecs: (j['uptime_secs'] as num?)?.toInt() ?? 0,
    );
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.releaseNotes,
  });

  final String currentVersion;
  final String? latestVersion;
  final bool updateAvailable;
  final String? releaseNotes;

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
    currentVersion: (j['current_version'] ?? '') as String,
    latestVersion: j['latest_version'] as String?,
    updateAvailable: (j['update_available'] ?? false) as bool,
    releaseNotes: j['release_notes'] as String?,
  );
}

class BackupItem {
  const BackupItem({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modified,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final String modified;

  factory BackupItem.fromJson(Map<String, dynamic> j) => BackupItem(
    name: (j['name'] ?? '') as String,
    path: (j['path'] ?? '') as String,
    sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
    modified: (j['modified'] ?? '') as String,
  );
}

class SnapshotItem {
  const SnapshotItem({
    required this.name,
    required this.created,
    required this.sizeBytes,
  });

  final String name;
  final String created;
  final int sizeBytes;

  factory SnapshotItem.fromJson(Map<String, dynamic> j) => SnapshotItem(
    name: (j['name'] ?? '') as String,
    created: (j['created'] ?? j['modified'] ?? '') as String,
    sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
  );
}

class DisplayInfo {
  const DisplayInfo({required this.brightness, required this.rotation});

  final int brightness;
  final int rotation;

  factory DisplayInfo.fromJson(Map<String, dynamic> j) => DisplayInfo(
    brightness: (j['brightness'] as num?)?.toInt() ?? 0,
    rotation: (j['rotation'] as num?)?.toInt() ?? 0,
  );

  DisplayInfo copyWith({int? brightness, int? rotation}) => DisplayInfo(
    brightness: brightness ?? this.brightness,
    rotation: rotation ?? this.rotation,
  );
}

class ServiceStatus {
  const ServiceStatus({
    required this.sshEnabled,
    required this.remoteEnabled,
    this.remoteExpiresInSecs,
  });

  final bool sshEnabled;
  final bool remoteEnabled;
  final int? remoteExpiresInSecs;

  factory ServiceStatus.fromJson(Map<String, dynamic> j) {
    final sshActive =
        (j['ssh_active'] ?? j['ssh_enabled'] ?? j['ssh']) as bool?;
    final remote =
        (j['remote_enabled'] ?? j['remote'] ?? sshActive ?? false) as bool;
    return ServiceStatus(
      sshEnabled: sshActive ?? remote,
      remoteEnabled: remote,
      remoteExpiresInSecs:
          (j['remote_expires_in_secs'] ?? j['expires_in_secs']) is num
          ? (j['remote_expires_in_secs'] ?? j['expires_in_secs'] as num).toInt()
          : null,
    );
  }
}

class BluetoothDevice {
  const BluetoothDevice({required this.address, required this.name});

  final String address;
  final String name;

  factory BluetoothDevice.fromJson(Map<String, dynamic> j) => BluetoothDevice(
    address: (j['address'] ?? '') as String,
    name: (j['name'] ?? j['address'] ?? '') as String,
  );
}

class PkgJob {
  const PkgJob({
    required this.jobId,
    required this.kind,
    required this.state,
    this.logTail = const [],
    this.error,
  });

  final String jobId;
  final String kind;
  final String state;
  final List<String> logTail;
  final String? error;

  bool get isDone => state == 'success' || state == 'failed';
  bool get ok => state == 'success';

  factory PkgJob.fromJson(Map<String, dynamic> j) => PkgJob(
    jobId: (j['job_id'] ?? '') as String,
    kind: (j['kind'] ?? '') as String,
    state: (j['state'] ?? 'running') as String,
    logTail: ((j['log_tail'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    error: j['error'] as String?,
  );
}

class SysdClient {
  SysdClient({this.socketPath = '/run/telepos/sysd.sock'});

  final String socketPath;

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      throw SysdException('sysd unreachable ($socketPath): $e');
    }

    try {
      final req = <String, dynamic>{
        'jsonrpc': '2.0',
        'method': method,
        'id': 1,
        if (params != null) 'params': params,
      };
      socket.add(utf8.encode('${jsonEncode(req)}\n'));
      await socket.flush();

      final buf = StringBuffer();
      final completer = Completer<String>();
      late StreamSubscription<List<int>> sub;
      sub = socket.listen(
        (data) {
          buf.write(utf8.decode(data));
          if (buf.toString().contains('\n') && !completer.isCompleted) {
            completer.complete(buf.toString());
          }
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(buf.toString());
        },
        cancelOnError: true,
      );

      final raw = await completer.future
          .timeout(const Duration(seconds: 130))
          .whenComplete(() => sub.cancel());
      final line = raw
          .split('\n')
          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      if (line.isEmpty) throw SysdException('empty response from sysd');

      final resp = jsonDecode(line) as Map<String, dynamic>;
      final err = resp['error'];
      if (err != null) {
        final msg = err is Map
            ? (err['message']?.toString() ?? 'error')
            : '$err';
        throw SysdException(msg);
      }
      return (resp['result'] as Map).cast<String, dynamic>();
    } finally {
      socket.destroy();
    }
  }

  Future<bool> available() async {
    try {
      await sessionStatus();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SessionStatus> sessionStatus() async =>
      SessionStatus.fromJson(await _call('session.status'));

  Future<void> switchSession(String mode) async =>
      _call('session.switch', {'mode': mode});

  Future<List<DriverItem>> catalog() async {
    final r = await _call('pkg.catalog');
    return ((r['items'] as List?) ?? const [])
        .map((e) => DriverItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> installDriver(String id) async =>
      (await _call('pkg.install', {'id': id, 'actor': 'pos'}))['job_id']
          as String;

  Future<String> removeDriver(String id) async =>
      (await _call('pkg.remove', {'id': id, 'actor': 'pos'}))['job_id']
          as String;

  Future<String> refresh() async =>
      (await _call('pkg.refresh'))['job_id'] as String;

  Future<PkgJob> job(String jobId) async =>
      PkgJob.fromJson(await _call('pkg.job', {'job_id': jobId}));

  Future<PkgJob> waitForJob(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    int maxPolls = 90,
  }) async {
    PkgJob j = await job(jobId);
    var polls = 0;
    while (!j.isDone && polls < maxPolls) {
      await Future<void>.delayed(interval);
      j = await job(jobId);
      polls++;
    }
    return j;
  }

  Future<NetworkStatus> networkStatus() async =>
      NetworkStatus.fromJson(await _call('network.status'));

  Future<List<WifiNetwork>> wifiScan() async {
    final r = await _call('network.wifi_scan');
    return ((r['networks'] as List?) ?? const [])
        .map((e) => WifiNetwork.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<({bool success, String message})> wifiConnect(
    String ssid, [
    String? password,
  ]) async {
    final r = await _call('network.wifi_connect', {
      'ssid': ssid,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return (
      success: (r['success'] ?? false) as bool,
      message: (r['message'] ?? '') as String,
    );
  }

  Future<bool> wifiDisconnect() async =>
      ((await _call('network.wifi_disconnect'))['success'] ?? false) as bool;

  Future<Map<String, dynamic>> ethernetStatus() async =>
      _call('network.ethernet_status');

  Future<({bool success, String mode})> ethernetConfigureDhcp(
    String iface,
  ) async {
    final r = await _call('network.ethernet_configure', {
      'interface': iface,
      'mode': 'dhcp',
    });
    return (
      success: (r['success'] ?? true) as bool,
      mode: (r['mode'] ?? 'dhcp') as String,
    );
  }

  Future<({bool success, String mode})> ethernetConfigureStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  }) async {
    final r = await _call('network.ethernet_configure', {
      'interface': iface,
      'mode': 'static',
      'ip': ipCidr,
      if (gateway != null && gateway.trim().isNotEmpty)
        'gateway': gateway.trim(),
      if (dns != null && dns.trim().isNotEmpty) 'dns': dns.trim(),
    });
    return (
      success: (r['success'] ?? true) as bool,
      mode: (r['mode'] ?? 'static') as String,
    );
  }

  Future<List<BluetoothDevice>> bluetoothScan() async {
    final r = await _call('hardware.bluetooth_scan');
    return ((r['devices'] as List?) ?? const [])
        .map(
          (e) => BluetoothDevice.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<({bool success, String message})> bluetoothPair(String address) async {
    final r = await _call('hardware.bluetooth_pair', {'address': address});
    return (
      success: (r['success'] ?? false) as bool,
      message: (r['message'] ?? '') as String,
    );
  }

  Future<List<Map<String, dynamic>>> usbList() async {
    final r = await _call('hardware.usb_list');
    return ((r['devices'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<SystemHealth> systemHealth() async =>
      SystemHealth.fromJson(await _call('system.health'));

  Future<void> reboot() async => _call('system.reboot');

  Future<void> shutdown() async => _call('system.shutdown');

  Future<void> factoryReset() async =>
      _call('system.factory_reset', {'confirm': true});

  Future<ExecResult> systemExec(
    String command, {
    int? timeout,
    String? cwd,
  }) async => ExecResult.fromJson(
    await _call('system.exec', {
      'command': command,
      if (timeout != null) 'timeout': timeout,
      if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
    }),
  );

  Future<SystemTime> getTime() async =>
      SystemTime.fromJson(await _call('system.get_time'));

  Future<({bool success, String timezone})> setTimezone(String timezone) async {
    final r = await _call('system.set_timezone', {'timezone': timezone});
    return (
      success: (r['success'] ?? false) as bool,
      timezone: (r['timezone'] ?? timezone) as String,
    );
  }

  Future<NtpSyncResult> ntpSync() async =>
      NtpSyncResult.fromJson(await _call('system.ntp_sync'));

  Future<UpdateInfo> updateVersion() async =>
      UpdateInfo.fromJson(await _call('update.version'));

  Future<UpdateInfo> updateCheck([String? url]) async => UpdateInfo.fromJson(
    await _call('update.check', {if (url != null) 'url': url}),
  );

  Future<String> updateDownload(String url) async =>
      (await _call('update.download', {'url': url}))['path'] as String? ?? '';

  Future<void> updateApply([String? path]) async =>
      _call('update.apply', {if (path != null) 'path': path});

  Future<void> updateRollback() async => _call('update.rollback');

  Future<List<BackupItem>> backupList() async {
    final r = await _call('backup.list');
    return ((r['backups'] as List?) ?? const [])
        .map((e) => BackupItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> backupCreate() async => _call('backup.create');

  Future<void> backupRestore(String name) async =>
      _call('backup.restore', {'name': name});

  Future<void> backupExportUsb(String name) async =>
      _call('backup.export_usb', {'name': name});

  Future<void> backupImportUsb() async => _call('backup.import_usb');

  Future<bool> snapshotAvailable() async =>
      ((await _call('snapshot.available'))['available'] ?? false) as bool;

  Future<List<SnapshotItem>> snapshotList() async {
    final r = await _call('snapshot.list');
    return ((r['snapshots'] as List?) ?? const [])
        .map(
          (e) => e is Map
              ? SnapshotItem.fromJson(e.cast<String, dynamic>())
              : SnapshotItem(name: e.toString(), created: '', sizeBytes: 0),
        )
        .toList();
  }

  Future<void> snapshotCreate([String? name]) async =>
      _call('snapshot.create', {if (name != null) 'name': name});

  Future<bool> snapshotRollback(String name) async {
    final r = await _call('snapshot.rollback', {'name': name});
    return (r['reboot_required'] ?? false) as bool;
  }

  Future<void> snapshotFactoryReset() async =>
      _call('snapshot.factory_reset', {'confirm': true});

  Future<DisplayInfo> displayInfo() async =>
      DisplayInfo.fromJson(await _call('display.info'));

  Future<int> displayGetBrightness() async =>
      ((await _call('display.get_brightness'))['brightness'] as num?)
          ?.toInt() ??
      0;

  Future<void> displaySetBrightness(int brightness) async =>
      _call('display.set_brightness', {'brightness': brightness});

  Future<void> displaySetRotation(int rotation) async =>
      _call('display.set_rotation', {'rotation': rotation});

  Future<ServiceStatus> serviceStatus() async =>
      ServiceStatus.fromJson(await _call('service.status'));

  Future<void> serviceRemoteEnable({int? minutes, String? pubkey}) async =>
      _call('service.remote_enable', {
        if (minutes != null) 'minutes': minutes,
        if (pubkey != null) 'pubkey': pubkey,
      });

  Future<void> serviceRemoteDisable() async => _call('service.remote_disable');
}
