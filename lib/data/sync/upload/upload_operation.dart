abstract class UploadOperation<T> {
  String get name;

  String get entityType;

  Future<UploadResult> execute({required List<T> items, int batchSize = 100});

  Future<int> getPendingCount() async {
    return 0;
  }

  Future<List<T>> getPendingItems({int limit = 100}) async {
    return [];
  }
}

class UploadResult {
  const UploadResult({
    required this.success,
    this.uploadedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
    this.failedIds = const [],
  });

  final bool success;

  final int uploadedCount;

  final int failedCount;

  final String? errorMessage;

  final List<String> failedIds;

  int get totalAttempted => uploadedCount + failedCount;

  bool get hasFailures => failedCount > 0;

  factory UploadResult.success({int uploadedCount = 0}) {
    return UploadResult(success: true, uploadedCount: uploadedCount);
  }

  factory UploadResult.partial({
    required int uploadedCount,
    required int failedCount,
    List<String> failedIds = const [],
  }) {
    return UploadResult(
      success: true,
      uploadedCount: uploadedCount,
      failedCount: failedCount,
      failedIds: failedIds,
    );
  }

  factory UploadResult.error(String message) {
    return UploadResult(success: false, errorMessage: message);
  }

  factory UploadResult.offline() {
    return const UploadResult(
      success: false,
      errorMessage: 'Network unavailable',
    );
  }

  factory UploadResult.nothingToUpload() {
    return const UploadResult(success: true, uploadedCount: 0);
  }

  @override
  String toString() {
    if (success) {
      if (hasFailures) {
        return 'UploadResult.partial($uploadedCount uploaded, $failedCount failed)';
      }
      return 'UploadResult.success($uploadedCount uploaded)';
    }
    return 'UploadResult.error($errorMessage)';
  }
}
