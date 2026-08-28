import 'app_bootstrap.dart';

/// What the first launch of an installation turned out to be.
enum FirstLaunchResult {
  newPosNoBackups,

  newPosWithBackups,

  existingUserNewPos,

  alreadyConfigured,

  offlineMode,
}

/// A backup this organization has, offered as something to restore from.
class FoundBackup {
  const FoundBackup({
    required this.posKey,
    required this.posName,
    required this.organizationName,
    required this.createdAt,
    required this.messageId,
    required this.checksum,
    required this.sizeBytes,
  });

  final String posKey;
  final String posName;
  final String organizationName;
  final DateTime createdAt;
  final int messageId;
  final String checksum;
  final int sizeBytes;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return '${createdAt.day.toString().padLeft(2, '0')}.'
        '${createdAt.month.toString().padLeft(2, '0')}.'
        '${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
  }

  Map<String, Object?> toJson() => {
    'posKey': posKey,
    'posName': posName,
    'organizationName': organizationName,
    'createdAt': createdAt.toIso8601String(),
    'messageId': messageId,
    'checksum': checksum,
    'sizeBytes': sizeBytes,
  };

  static FoundBackup fromJson(Map<String, dynamic> json) => FoundBackup(
    posKey: json['posKey'] as String? ?? '',
    posName: json['posName'] as String? ?? '',
    organizationName: json['organizationName'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    messageId: json['messageId'] as int? ?? 0,
    checksum: json['checksum'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
  );
}

/// The questions the splash screen and the restore-or-new fork ask before an
/// installation exists: is this configured, are there backups to restore from,
/// is there an organization this till should join.
///
/// Answering them means reading the database and talking to Telegram. Neither
/// belongs to a screen, and neither exists in a browser.
abstract interface class FirstLaunchRepository {
  Future<FirstLaunchResult> determineResult();

  Future<List<FoundBackup>> findAvailableBackups();

  Future<bool> restoreFromBackup(FoundBackup backup, {BootProgress? onProgress});

  /// Pulls the organization's shared catalog down onto a till that is joining
  /// an existing organization.
  Future<bool> loadGlobalData({BootProgress? onProgress});

  /// Starts this till fresh instead of restoring: mints its POS key and stores
  /// it. Returns the key.
  ///
  /// Minting and storing are one operation because a key that is generated and
  /// not stored leaves the till unidentifiable on the next boot.
  Future<String> startNewPos();
}
