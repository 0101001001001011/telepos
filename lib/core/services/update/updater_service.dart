import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../data/database/app_database.dart';
import '../../constants/app_constants.dart';
import '../../platform/platform_info.dart';
import '../../utils/update_util.dart';
import '../../utils/version_util.dart';
import 'update_info.dart';
import 'update_state.dart';

class UpdaterService {
  UpdaterService({Version? currentVersion, Dio? dio, AppDatabase? database})
    : _currentVersion =
          currentVersion ?? Version.parse(AppConstants.appVersion),
      _dio = dio ?? Dio(),
      _database = database;

  final Version _currentVersion;
  final Dio _dio;
  final AppDatabase? _database;

  String? _downloadedInstallerPath;

  final _stateController = StreamController<UpdateState>.broadcast();
  UpdateState _state = const UpdateState.idle();

  Stream<UpdateState> get stateStream => _stateController.stream;

  UpdateState get state => _state;

  Version get currentVersion => _currentVersion;

  void _updateState(UpdateState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Future<void> checkForUpdates() async {
    if (!PlatformInfo.isDesktop) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.idle,
          errorMessage: _getMobileUpdateMessage(),
        ),
      );
      return;
    }

    _updateState(_state.copyWith(status: UpdateStatus.checking));

    try {
      final updateInfo = await _checkGitHubRelease();

      if (updateInfo == null) {
        _updateState(const UpdateState.idle());
        return;
      }

      _updateState(
        _state.copyWith(status: UpdateStatus.available, updateInfo: updateInfo),
      );
    } on SocketException {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.idle,
          errorMessage: 'No network connection, update check skipped',
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _updateState(
          _state.copyWith(
            status: UpdateStatus.idle,
            errorMessage: 'Update check timed out, will retry later',
          ),
        );
      } else {
        _updateState(
          _state.copyWith(
            status: UpdateStatus.failed,
            errorMessage: 'Failed to check for updates: ${e.message}',
          ),
        );
      }
    } catch (e) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          errorMessage: 'Failed to check for updates: $e',
        ),
      );
    }
  }

  String _getMobileUpdateMessage() {
    if (PlatformInfo.isAndroid) {
      return 'Updates are available through Google Play Store';
    } else if (PlatformInfo.isIOS) {
      return 'Updates are available through App Store';
    } else if (PlatformInfo.isWeb) {
      return 'Web version updates automatically';
    }
    return 'Updates are managed through app store';
  }

  Future<UpdateInfo?> _checkGitHubRelease() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConstants.githubReleasesUrl,
      options: Options(
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'TelePOS/${AppConstants.appVersion}',
        },
        receiveTimeout: AppConstants.updateCheckTimeout,
        sendTimeout: AppConstants.updateCheckTimeout,
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      return null;
    }

    final json = response.data!;

    final tagName = json['tag_name'] as String? ?? '';
    if (tagName.isEmpty) return null;

    final serverVersion = Version.parse(tagName);

    if (serverVersion <= _currentVersion) {
      return null;
    }

    final assets = json['assets'] as List<dynamic>? ?? [];
    String? downloadUrl;
    int fileSize = 0;
    String? fallbackUrl;
    int fallbackSize = 0;

    for (final asset in assets) {
      final assetMap = asset as Map<String, dynamic>;
      final name = assetMap['name'] as String? ?? '';
      final isExe = name.endsWith('.exe');
      if (isExe && name.startsWith('TelePOS_Setup_')) {
        downloadUrl = assetMap['browser_download_url'] as String?;
        fileSize = assetMap['size'] as int? ?? 0;
        break;
      }
      if (isExe && name.startsWith('TelePOS_Setup_')) {
        fallbackUrl = assetMap['browser_download_url'] as String?;
        fallbackSize = assetMap['size'] as int? ?? 0;
      }
    }
    downloadUrl ??= fallbackUrl;
    if (downloadUrl != null && fileSize == 0) fileSize = fallbackSize;

    if (downloadUrl == null) {
      return null;
    }

    final releaseNotes = json['body'] as String? ?? '';
    final releaseDateStr = json['published_at'] as String? ?? '';
    final releaseDate = releaseDateStr.isNotEmpty
        ? DateTime.parse(releaseDateStr)
        : DateTime.now();

    return UpdateInfo(
      version: serverVersion,
      currentVersion: _currentVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      fileSize: fileSize,
      checksum: '',
      releaseDate: releaseDate,
    );
  }

  void skipUpdate() {
    if (_state.status != UpdateStatus.available) return;

    final info = _state.updateInfo;
    if (info != null && !info.canSkip) {
      return;
    }

    _updateState(_state.copyWith(status: UpdateStatus.skipped));
  }

  Future<void> downloadUpdate() async {
    if (_state.updateInfo == null) return;

    _updateState(
      _state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0.0),
    );

    try {
      _downloadedInstallerPath = await _downloadFile(_state.updateInfo!);

      _updateState(
        _state.copyWith(
          status: UpdateStatus.ready,
          downloadProgress: 1.0,
          canUpdate: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          errorMessage: 'Download failed: $e',
        ),
      );
    }
  }

  Future<String> _downloadFile(UpdateInfo info) async {
    final tempDir = UpdateUtil.getTempDirectory();
    await tempDir.create(recursive: true);

    final version = info.version.toString();
    final fileName = 'TelePOS_Setup_$version.exe';
    final filePath = '${tempDir.path}/$fileName';

    await _dio.download(
      info.downloadUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          _updateState(_state.copyWith(downloadProgress: progress));
        }
      },
    );

    return filePath;
  }

  Future<bool> performPreUpdateChecks() async {
    _updateState(_state.copyWith(status: UpdateStatus.preUpdateCheck));

    final blockReasons = <String>[];

    try {
      if (await _hasOpenShift()) {
        blockReasons.add(UpdateBlockReason.shiftOpen.message);
      }

      final canUpdate = blockReasons.isEmpty;

      _updateState(
        _state.copyWith(
          status: canUpdate ? UpdateStatus.ready : UpdateStatus.available,
          canUpdate: canUpdate,
          pendingSyncItems: blockReasons,
        ),
      );

      return canUpdate;
    } catch (e) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          errorMessage: 'Pre-update check failed: $e',
        ),
      );
      return false;
    }
  }

  Future<bool> _hasOpenShift() async {
    final db = _database;
    if (db == null) return false;
    final shift = await db.shiftDao.findOpenedShift();
    return shift != null;
  }

  Future<void> installUpdate() async {
    if (_downloadedInstallerPath == null) return;

    _updateState(_state.copyWith(status: UpdateStatus.installing));

    try {
      final installerPath = _downloadedInstallerPath!;
      final installerFile = File(installerPath);

      if (!await installerFile.exists()) {
        throw const UpdateException('Installer file not found');
      }

      final currentExe = Platform.resolvedExecutable;
      final currentDir = File(currentExe).parent.path;

      await Process.start(installerPath, [
        '/SILENT',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
        '/DIR=$currentDir',
      ], mode: ProcessStartMode.detached);

      _updateState(_state.copyWith(status: UpdateStatus.complete));

      exit(0);
    } catch (e) {
      _updateState(
        _state.copyWith(
          status: UpdateStatus.failed,
          errorMessage: 'Installation failed: $e',
        ),
      );
    }
  }

  void reset() {
    _updateState(const UpdateState.idle());
    _downloadedInstallerPath = null;
  }

  void dispose() {
    _stateController.close();
    _dio.close();
  }
}
