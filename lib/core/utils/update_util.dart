import 'dart:io';

import '../platform/platform_info.dart';

class UpdateUtil {
  UpdateUtil._();

  static const String appName = 'TelePOS';

  static const String updateFileName = 'telepos_update';

  static Directory getInstallDirectory() {
    if (PlatformInfo.isWindows) {
      final localAppData =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'];
      if (localAppData == null) {
        throw const UpdateException('Cannot determine LOCALAPPDATA directory');
      }
      return Directory('$localAppData/$appName');
    }

    if (PlatformInfo.isLinux) {
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw const UpdateException('Cannot determine HOME directory');
      }
      return Directory('$home/.local/share/$appName');
    }

    if (PlatformInfo.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw const UpdateException('Cannot determine HOME directory');
      }
      return Directory('$home/Library/Application Support/$appName');
    }

    throw UnsupportedError('Unsupported platform for updates');
  }

  static Directory getTempDirectory() {
    return Directory('${Directory.systemTemp.path}/$appName-update');
  }

  static String getExecutablePath() {
    return Platform.resolvedExecutable;
  }

  static String getUpdateScriptPath() {
    final tempDir = getTempDirectory();
    if (PlatformInfo.isWindows) {
      return '${tempDir.path}/update.bat';
    }
    return '${tempDir.path}/update.sh';
  }

  static String generateUpdateScript({
    required String newExecutablePath,
    required String targetExecutablePath,
    required int currentPid,
  }) {
    if (PlatformInfo.isWindows) {
      return _generateWindowsScript(
        newExecutablePath: newExecutablePath,
        targetExecutablePath: targetExecutablePath,
        currentPid: currentPid,
      );
    }

    return _generateUnixScript(
      newExecutablePath: newExecutablePath,
      targetExecutablePath: targetExecutablePath,
      currentPid: currentPid,
    );
  }

  static String _generateWindowsScript({
    required String newExecutablePath,
    required String targetExecutablePath,
    required int currentPid,
  }) {
    final newPath = newExecutablePath.replaceAll('/', '\\');
    final targetPath = targetExecutablePath.replaceAll('/', '\\');

    return '''
@echo off
setlocal

echo TelePOS Update Script
echo Waiting for application to close...

:wait_loop
tasklist /FI "PID eq $currentPid" 2>NUL | find /I "$currentPid" >NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 1 /nobreak >NUL
    goto wait_loop
)

echo Replacing executable...
move /Y "$targetPath" "$targetPath.old" >NUL 2>&1
copy /Y "$newPath" "$targetPath" >NUL

if %ERRORLEVEL% NEQ 0 (
    echo Update failed, restoring backup...
    move /Y "$targetPath.old" "$targetPath" >NUL 2>&1
    exit /b 1
)

echo Cleaning up...
del /F /Q "$targetPath.old" >NUL 2>&1
del /F /Q "$newPath" >NUL 2>&1

echo Starting updated application...
start "" "$targetPath"

echo Update complete!
exit /b 0
''';
  }

  static String _generateUnixScript({
    required String newExecutablePath,
    required String targetExecutablePath,
    required int currentPid,
  }) {
    return '''
#!/bin/bash

echo "TelePOS Update Script"
echo "Waiting for application to close..."

while kill -0 $currentPid 2>/dev/null; do
    sleep 1
done

echo "Replacing executable..."
mv "$targetExecutablePath" "$targetExecutablePath.old" 2>/dev/null
cp "$newExecutablePath" "$targetExecutablePath"

if [ \$? -ne 0 ]; then
    echo "Update failed, restoring backup..."
    mv "$targetExecutablePath.old" "$targetExecutablePath" 2>/dev/null
    exit 1
fi

chmod +x "$targetExecutablePath"

echo "Cleaning up..."
rm -f "$targetExecutablePath.old" 2>/dev/null
rm -f "$newExecutablePath" 2>/dev/null

echo "Starting updated application..."
"$targetExecutablePath" &

echo "Update complete!"
exit 0
''';
  }

  static Future<File> writeUpdateScript({
    required String newExecutablePath,
    required String targetExecutablePath,
    required int currentPid,
  }) async {
    final scriptPath = getUpdateScriptPath();
    final scriptContent = generateUpdateScript(
      newExecutablePath: newExecutablePath,
      targetExecutablePath: targetExecutablePath,
      currentPid: currentPid,
    );

    final file = File(scriptPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(scriptContent);

    if (!PlatformInfo.isWindows) {
      await Process.run('chmod', ['+x', scriptPath]);
    }

    return file;
  }

  static Future<void> executeUpdateScript() async {
    final scriptPath = getUpdateScriptPath();

    if (PlatformInfo.isWindows) {
      await Process.start('cmd', [
        '/c',
        scriptPath,
      ], mode: ProcessStartMode.detached);
    } else {
      await Process.start('/bin/bash', [
        scriptPath,
      ], mode: ProcessStartMode.detached);
    }
  }

  static Future<bool> isInstallDirectoryWritable() async {
    try {
      final dir = getInstallDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final testFile = File('${dir.path}/.write_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String getDownloadExtension() {
    if (PlatformInfo.isWindows) return '.exe';
    if (PlatformInfo.isMacOS) return '.dmg';
    if (PlatformInfo.isLinux) return '.AppImage';
    return '';
  }

  static String getDownloadUrl({
    required String baseUrl,
    required String version,
  }) {
    final ext = getDownloadExtension();
    final platform = _getPlatformSuffix();
    return '$baseUrl/v$version/${updateFileName}_${version}_$platform$ext';
  }

  static String _getPlatformSuffix() {
    if (PlatformInfo.isWindows) return 'windows';
    if (PlatformInfo.isMacOS) return 'macos';
    if (PlatformInfo.isLinux) return 'linux';
    return 'unknown';
  }

  static int getCurrentPid() => pid;

  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = getTempDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => 'UpdateException: $message';
}
