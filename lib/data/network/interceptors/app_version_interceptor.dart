import 'request_interceptor.dart';

class AppVersionStatusInterceptor extends RequestInterceptor {
  AppVersionStatusInterceptor({
    required this.currentVersion,
    this.onUpdateRequired,
    this.onUpdateAvailable,
  });

  final String currentVersion;

  final void Function(String minVersion)? onUpdateRequired;

  final void Function(String latestVersion)? onUpdateAvailable;

  @override
  String get name => 'AppVersionStatusInterceptor';

  @override
  int get priority => 90;

  @override
  Future<NetworkResponse> onResponse(NetworkResponse response) async {
    final minVersion = response.getHeader('X-Min-App-Version');
    if (minVersion != null) {
      if (_isVersionLower(currentVersion, minVersion)) {
        onUpdateRequired?.call(minVersion);
      }
    }

    final latestVersion = response.getHeader('X-Latest-App-Version');
    if (latestVersion != null) {
      if (_isVersionLower(currentVersion, latestVersion)) {
        onUpdateAvailable?.call(latestVersion);
      }
    }

    return response;
  }

  bool _isVersionLower(String version1, String version2) {
    final parts1 = version1
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final parts2 = version2
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (var i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return true;
      if (parts1[i] > parts2[i]) return false;
    }

    return false;
  }
}

enum AppVersionStatus { ok, updateAvailable, updateRequired }
