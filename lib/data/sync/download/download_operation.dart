abstract class DownloadOperation<T> {
  String get name;

  String get entityType;

  Future<DownloadResult<T>> execute({DateTime? since, int batchSize = 100});
}

class DownloadResult<T> {
  const DownloadResult({
    required this.success,
    this.items = const [],
    this.hasMore = false,
    this.lastModified,
    this.errorMessage,
    this.totalCount,
  });

  final bool success;

  final List<T> items;

  final bool hasMore;

  final DateTime? lastModified;

  final String? errorMessage;

  final int? totalCount;

  int get count => items.length;

  factory DownloadResult.success(
    List<T> items, {
    bool hasMore = false,
    DateTime? lastModified,
    int? totalCount,
  }) {
    return DownloadResult(
      success: true,
      items: items,
      hasMore: hasMore,
      lastModified: lastModified,
      totalCount: totalCount ?? items.length,
    );
  }

  factory DownloadResult.empty() {
    return const DownloadResult(success: true, items: [], hasMore: false);
  }

  factory DownloadResult.error(String message) {
    return DownloadResult(success: false, errorMessage: message);
  }

  factory DownloadResult.offline() {
    return const DownloadResult(
      success: false,
      errorMessage: 'Network unavailable',
    );
  }

  @override
  String toString() {
    if (success) {
      return 'DownloadResult.success(${items.length} items, hasMore: $hasMore)';
    }
    return 'DownloadResult.error($errorMessage)';
  }
}
