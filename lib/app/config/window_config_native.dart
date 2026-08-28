import 'dart:io';
import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import 'package:telepos/core/platform/platform_info.dart';

const _minSize = Size(1024, 768);
const _devSize = Size(1024, 768);
const _title = 'TelePOS';

Future<void> initWindow({bool isProduction = false}) async {
  if (!PlatformInfo.isDesktop) return;

  await windowManager.ensureInitialized();

  final options = WindowOptions(
    size: _devSize,
    minimumSize: _minSize,
    center: true,
    title: _title,
    titleBarStyle: isProduction ? TitleBarStyle.hidden : TitleBarStyle.normal,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    if (isProduction) {
      await windowManager.setFullScreen(true);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setPreventClose(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<bool> acquireSingleInstanceLock() async {
  if (!PlatformInfo.isDesktop) return true;

  try {
    final lockDir =
        Platform.environment['TEMP'] ??
        Platform.environment['TMPDIR'] ??
        '/tmp';
    final lockFile = File('$lockDir/telepos.lock');

    if (await lockFile.exists()) {
      final pidStr = await lockFile.readAsString();
      final lockedPid = int.tryParse(pidStr.trim());
      if (lockedPid != null && _isProcessRunning(lockedPid)) {
        return false;
      }
    }

    await lockFile.writeAsString('$pid');
    return true;
  } catch (_) {
    return true;
  }
}

Future<void> releaseSingleInstanceLock() async {
  if (!PlatformInfo.isDesktop) return;

  try {
    final lockDir =
        Platform.environment['TEMP'] ??
        Platform.environment['TMPDIR'] ??
        '/tmp';
    final lockFile = File('$lockDir/telepos.lock');
    if (await lockFile.exists()) {
      await lockFile.delete();
    }
  } catch (_) {}
}

bool _isProcessRunning(int processId) {
  try {
    if (Platform.isWindows) {
      final result = Process.runSync('tasklist', ['/FI', 'PID eq $processId']);
      return result.stdout.toString().contains('$processId');
    } else {
      final result = Process.runSync('kill', ['-0', '$processId']);
      return result.exitCode == 0;
    }
  } catch (_) {
    return false;
  }
}
