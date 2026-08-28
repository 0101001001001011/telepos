import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../platform/platform_info.dart';
import '../../utils/version_util.dart';

class StoreUpdateService {
  StoreUpdateService({
    String? appStoreId,
    String? playStoreId,
    Version? currentVersion,
  }) : _appStoreId = appStoreId ?? 'com.telepos.app',
       _playStoreId = playStoreId ?? 'com.telepos.app',
       _currentVersion = currentVersion ?? Version.parse('1.0.0');

  final String _appStoreId;
  final String _playStoreId;
  final Version _currentVersion;

  final _stateController = StreamController<StoreUpdateState>.broadcast();

  Stream<StoreUpdateState> get stateStream => _stateController.stream;

  Version get currentVersion => _currentVersion;

  Future<StoreUpdateInfo?> checkForUpdate() async {
    if (!PlatformInfo.isMobile) {
      return null;
    }

    _stateController.add(StoreUpdateState.checking);

    try {
      if (PlatformInfo.isIOS) {
        return await _checkAppStoreUpdate();
      } else if (PlatformInfo.isAndroid) {
        return await _checkPlayStoreUpdate();
      }

      return null;
    } catch (e) {
      _stateController.add(StoreUpdateState.error);
      return null;
    }
  }

  Future<StoreUpdateInfo?> _checkAppStoreUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 1));

    _stateController.add(StoreUpdateState.upToDate);
    return null;
  }

  Future<StoreUpdateInfo?> _checkPlayStoreUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 1));

    _stateController.add(StoreUpdateState.upToDate);
    return null;
  }

  Future<void> openStorePage() async {
    _stateController.add(StoreUpdateState.redirecting);

    try {
      final url = _getStoreUrl();

      debugPrint('[StoreUpdateService] Opening store URL: $url');

      _stateController.add(StoreUpdateState.idle);
    } catch (e) {
      _stateController.add(StoreUpdateState.error);
    }
  }

  String _getStoreUrl() {
    if (PlatformInfo.isIOS) {
      return 'https://apps.apple.com/app/id$_appStoreId';
    }

    if (PlatformInfo.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=$_playStoreId';
    }

    return '';
  }

  Future<void> startFlexibleUpdate() async {
    if (!PlatformInfo.isAndroid) return;

    _stateController.add(StoreUpdateState.downloading);

    await Future<void>.delayed(const Duration(seconds: 2));
    _stateController.add(StoreUpdateState.readyToInstall);
  }

  Future<void> completeFlexibleUpdate() async {
    if (!PlatformInfo.isAndroid) return;

    _stateController.add(StoreUpdateState.installing);
  }

  Future<void> startImmediateUpdate() async {
    if (!PlatformInfo.isAndroid) return;

    _stateController.add(StoreUpdateState.updating);

    _stateController.add(StoreUpdateState.cancelled);
  }

  Future<void> requestReview() async {}

  void dispose() {
    _stateController.close();
  }
}

enum StoreUpdateState {
  idle,

  checking,

  upToDate,

  updateAvailable,

  downloading,

  readyToInstall,

  installing,

  updating,

  redirecting,

  cancelled,

  error,
}

class StoreUpdateInfo {
  const StoreUpdateInfo({
    required this.currentVersion,
    required this.storeVersion,
    required this.storeUrl,
    required this.platform,
    this.releaseNotes = '',
    this.updatePriority = UpdatePriority.normal,
    this.staleDays = 0,
  });

  final Version currentVersion;

  final Version storeVersion;

  final String storeUrl;

  final StorePlatform platform;

  final String releaseNotes;

  final UpdatePriority updatePriority;

  final int staleDays;

  bool get isCritical => updatePriority == UpdatePriority.critical;

  bool get shouldShowImmediate =>
      isCritical || staleDays > 7 || updatePriority == UpdatePriority.high;
}

enum StorePlatform { appStore, playStore }

enum UpdatePriority { normal, low, medium, high, critical }
