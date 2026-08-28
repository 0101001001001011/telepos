import 'dart:async';

import 'package:telepos/app/jobs/job_scheduler.dart';

class UpdateInfo {
  final String version;
  final String? releaseNotes;
  final String? downloadUrl;
  final bool isMandatory;
  final DateTime releaseDate;

  UpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    required this.isMandatory,
    required this.releaseDate,
  });
}

typedef CheckForUpdateCallback =
    Future<UpdateInfo?> Function(String currentVersion);

class UpdateCheckerJob extends BackgroundJob {
  final CheckForUpdateCallback _checkForUpdate;
  final String _currentVersion;
  final void Function(UpdateInfo)? onUpdateAvailable;

  UpdateInfo? _lastKnownUpdate;

  UpdateCheckerJob({
    required CheckForUpdateCallback checkForUpdate,
    required String currentVersion,
    this.onUpdateAvailable,
  }) : _checkForUpdate = checkForUpdate,
       _currentVersion = currentVersion;

  @override
  String get id => 'update_checker';

  @override
  String get name => 'Update Checker';

  @override
  Duration get interval => const Duration(hours: 3);

  @override
  JobPriority get priority => JobPriority.low;

  @override
  Duration get timeout => const Duration(minutes: 2);

  @override
  int get maxRetries => 3;

  @override
  Duration get retryDelay => const Duration(minutes: 10);

  UpdateInfo? get lastKnownUpdate => _lastKnownUpdate;

  @override
  Future<void> execute() async {
    final updateInfo = await _checkForUpdate(_currentVersion);

    if (updateInfo != null) {
      if (_lastKnownUpdate?.version != updateInfo.version) {
        _lastKnownUpdate = updateInfo;
        onUpdateAvailable?.call(updateInfo);
      }
    }
  }
}
