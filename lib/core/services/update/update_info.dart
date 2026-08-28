import '../../utils/version_util.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fileSize,
    required this.checksum,
    required this.releaseDate,
    this.isMandatory = false,
    this.minRequiredVersion,
  });

  final Version version;

  final Version currentVersion;

  final String downloadUrl;

  final String releaseNotes;

  final int fileSize;

  final String checksum;

  final DateTime releaseDate;

  final bool isMandatory;

  final Version? minRequiredVersion;

  bool get canSkip => !isMandatory;

  String get fileSizeFormatted {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (fileSize >= gb) {
      return '${(fileSize / gb).toStringAsFixed(1)} GB';
    }
    if (fileSize >= mb) {
      return '${(fileSize / mb).toStringAsFixed(1)} MB';
    }
    if (fileSize >= kb) {
      return '${(fileSize / kb).toStringAsFixed(1)} KB';
    }
    return '$fileSize B';
  }

  String get versionString => version.toString();

  factory UpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required Version currentVersion,
  }) {
    return UpdateInfo(
      version: Version.parse(json['version'] as String),
      currentVersion: currentVersion,
      downloadUrl: json['downloadUrl'] as String,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      checksum: json['checksum'] as String? ?? '',
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      isMandatory: json['isMandatory'] as bool? ?? false,
      minRequiredVersion: json['minRequiredVersion'] != null
          ? Version.parse(json['minRequiredVersion'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'UpdateInfo(version: $version, mandatory: $isMandatory, '
        'size: $fileSizeFormatted)';
  }
}
